# frozen_string_literal: true

require 'spec_helper'
require 'securerandom'
require 'tempfile'
require 'logger'
require 'cloud'

describe Bosh::AzureCloud::Cloud do
  before(:all) do
    @subscription_id                 = ENV['BOSH_AZURE_SUBSCRIPTION_ID']                 || raise('Missing BOSH_AZURE_SUBSCRIPTION_ID')
    @tenant_id                       = ENV['BOSH_AZURE_TENANT_ID']                       || raise('Missing BOSH_AZURE_TENANT_ID')
    @client_id                       = ENV['BOSH_AZURE_CLIENT_ID']                       || raise('Missing BOSH_AZURE_CLIENT_ID')
    @client_secret                   = ENV['BOSH_AZURE_CLIENT_SECRET']                   || raise('Missing BOSH_AZURE_CLIENT_SECRET')
    @stemcell_id                     = ENV['BOSH_AZURE_STEMCELL_ID']                     || raise('Missing BOSH_AZURE_STEMCELL_ID')
    @ssh_public_key                  = ENV['BOSH_AZURE_SSH_PUBLIC_KEY']                  || raise('Missing BOSH_AZURE_SSH_PUBLIC_KEY')
    @default_security_group          = ENV['BOSH_AZURE_DEFAULT_SECURITY_GROUP']          || raise('Missing BOSH_AZURE_DEFAULT_SECURITY_GROUP')
    @default_resource_group_name     = ENV['BOSH_AZURE_DEFAULT_RESOURCE_GROUP_NAME']     || raise('Missing BOSH_AZURE_DEFAULT_RESOURCE_GROUP_NAME')
    @application_gateway_name        = ENV['BOSH_AZURE_APPLICATION_GATEWAY_NAME']        || raise('Missing BOSH_AZURE_APPLICATION_GATEWAY_NAME')
  end

  let(:azure_environment)          { ENV.fetch('BOSH_AZURE_ENVIRONMENT', 'AzureCloud') }
  let(:location)                   { ENV.fetch('BOSH_AZURE_LOCATION', 'westcentralus') }
  let(:storage_account_name)       { ENV.fetch('BOSH_AZURE_STORAGE_ACCOUNT_NAME', nil) }
  let(:extra_storage_account_name) { ENV.fetch('BOSH_AZURE_EXTRA_STORAGE_ACCOUNT_NAME', nil) }
  let(:use_managed_disks)          { ENV.fetch('BOSH_AZURE_USE_MANAGED_DISKS', false).to_s == 'true' }
  let(:vnet_name)                  { ENV.fetch('BOSH_AZURE_VNET_NAME', 'boshvnet-crp') }
  let(:subnet_name)                { ENV.fetch('BOSH_AZURE_MANUAL_SUBNET_1_NAME', 'BOSH1') }
  let(:instance_type)              { ENV.fetch('BOSH_AZURE_INSTANCE_TYPE', 'Standard_D1_v2') }
  let(:vm_metadata)                { { deployment: 'deployment', job: 'cpi_spec', index: '0', delete_me: 'please' } }
  let(:network_spec)               { {} }
  let(:vm_properties)              { { 'instance_type' => instance_type } }

  let(:azure_config_hash) do
    {
      'environment' => azure_environment,
      'subscription_id' => @subscription_id,
      'resource_group_name' => @default_resource_group_name,
      'tenant_id' => @tenant_id,
      'client_id' => @client_id,
      'client_secret' => @client_secret,
      'ssh_user' => 'vcap',
      'ssh_public_key' => @ssh_public_key,
      'default_security_group' => @default_security_group,
      'parallel_upload_thread_num' => 16
    }
  end

  let(:azure_config) do
    Bosh::AzureCloud::AzureConfig.new(azure_config_hash)
  end

  let(:cloud_options) do
    {
      'azure' => azure_config_hash,
      'registry' => {
        'endpoint' => 'fake',
        'user' => 'fake',
        'password' => 'fake'
      }
    }
  end

  subject(:cpi) do
    cloud_options['azure']['storage_account_name'] = storage_account_name unless storage_account_name.nil?
    cloud_options['azure']['use_managed_disks'] = use_managed_disks
    described_class.new(cloud_options)
  end

  before do
    Bosh::Clouds::Config.configure(double('delegate', task_checkpoint: nil))
  end

  before { allow(Bosh::Clouds::Config).to receive_messages(logger: logger) }
  let(:logger) { Logger.new(STDERR) }

  before { allow(Bosh::Cpi::RegistryClient).to receive_messages(new: double('registry').as_null_object) }

  before { @disk_id_pool = [] }
  after do
    @disk_id_pool.each do |disk_id|
      logger.info("Cleanup: Deleting the disk '#{disk_id}'")
      cpi.delete_disk(disk_id) if disk_id
    end
  end

  context 'when application_gateway is specified in resource pool' do
    let(:network_spec) do
      {
        'network_a' => {
          'type' => 'manual',
          'ip' => "10.0.0.#{Random.rand(10..99)}",
          'cloud_properties' => {
            'virtual_network_name' => vnet_name,
            'subnet_name' => subnet_name
          }
        }
      }
    end

    let(:vm_properties) do
      {
        'instance_type' => instance_type,
        'application_gateway' => @application_gateway_name
      }
    end

    let(:threads) { 2 }
    let(:ip_address_start) do
      Random.rand(10..(100 - threads))
    end
    let(:ip_address_end) do
      ip_address_start + threads - 1
    end
    let(:ip_address_specs) do
      (ip_address_start..ip_address_end).to_a.collect { |x| "10.0.0.#{x}" }
    end
    let(:network_specs) do
      ip_address_specs.collect do |ip_address_spec|
        {
          'network_a' => {
            'type' => 'manual',
            'ip' => ip_address_spec,
            'cloud_properties' => {
              'virtual_network_name' => vnet_name,
              'subnet_name' => subnet_name
            }
          }
        }
      end
    end

    it 'should add the VM to the backend pool of application gateway' do
      ag_url = cpi.azure_client.rest_api_url(
        Bosh::AzureCloud::AzureClient::REST_API_PROVIDER_NETWORK,
        Bosh::AzureCloud::AzureClient::REST_API_APPLICATION_GATEWAYS,
        name: @application_gateway_name
      )

      lifecycles = []
      threads.times do |i|
        lifecycles[i] = Thread.new do
          agent_id = SecureRandom.uuid
          ip_config_id = "/subscriptions/#{@subscription_id}/resourceGroups/#{@default_resource_group_name}/providers/Microsoft.Network/networkInterfaces/#{agent_id}-0/ipConfigurations/ipconfig0"
          begin
            new_instance_id = cpi.create_vm(
              agent_id,
              @stemcell_id,
              vm_properties,
              network_specs[i]
            )
            ag = cpi.azure_client.get_resource_by_id(ag_url)
            expect(ag['properties']['backendAddressPools'][0]['properties']['backendIPConfigurations']).to include(
              'id' => ip_config_id
            )
          ensure
            cpi.delete_vm(new_instance_id) if new_instance_id
          end
          ag = cpi.azure_client.get_resource_by_id(ag_url)
          unless ag['properties']['backendAddressPools'][0]['properties']['backendIPConfigurations'].nil?
            expect(ag['properties']['backendAddressPools'][0]['properties']['backendIPConfigurations']).not_to include(
              'id' => ip_config_id
            )
          end
        end
      end
      lifecycles.each(&:join)
    end
  end
end
