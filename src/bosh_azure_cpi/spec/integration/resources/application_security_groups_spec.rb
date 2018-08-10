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
    @additional_resource_group_name  = ENV['BOSH_AZURE_ADDITIONAL_RESOURCE_GROUP_NAME']  || raise('Missing BOSH_AZURE_ADDITIONAL_RESOURCE_GROUP_NAME')
    @primary_public_ip               = ENV['BOSH_AZURE_PRIMARY_PUBLIC_IP']               || raise('Missing BOSH_AZURE_PRIMARY_PUBLIC_IP')
    @secondary_public_ip             = ENV['BOSH_AZURE_SECONDARY_PUBLIC_IP']             || raise('Missing BOSH_AZURE_SECONDARY_PUBLIC_IP')
    @application_gateway_name        = ENV['BOSH_AZURE_APPLICATION_GATEWAY_NAME']        || raise('Missing BOSH_AZURE_APPLICATION_GATEWAY_NAME')
    @application_security_group      = ENV['BOSH_AZURE_APPLICATION_SECURITY_GROUP']      || raise('Missing BOSH_AZURE_APPLICATION_SECURITY_GROUP')
  end

  let(:azure_environment)          { ENV.fetch('BOSH_AZURE_ENVIRONMENT', 'AzureCloud') }
  let(:location)                   { ENV.fetch('BOSH_AZURE_LOCATION', 'westcentralus') }
  let(:storage_account_name)       { ENV.fetch('BOSH_AZURE_STORAGE_ACCOUNT_NAME', nil) }
  let(:extra_storage_account_name) { ENV.fetch('BOSH_AZURE_EXTRA_STORAGE_ACCOUNT_NAME', nil) }
  let(:use_managed_disks)          { ENV.fetch('BOSH_AZURE_USE_MANAGED_DISKS', false).to_s == 'true' }
  let(:vnet_name)                  { ENV.fetch('BOSH_AZURE_VNET_NAME', 'boshvnet-crp') }
  let(:subnet_name)                { ENV.fetch('BOSH_AZURE_DYNAMIC_SUBNET_NAME', 'BOSH1') }
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

  context 'when assigning application security groups to VM NIC', application_security_group: true do
    let(:network_spec) do
      {
        'network_a' => {
          'type' => 'dynamic',
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
        'application_security_groups' => [@application_security_group]
      }
    end

    it 'should exercise the vm lifecycle' do
      vm_lifecycle do |instance_id|
        instance_id_obj = Bosh::AzureCloud::InstanceId.parse(instance_id, azure_config)
        network_interface = cpi.azure_client.get_network_interface_by_name(@default_resource_group_name, "#{instance_id_obj.vm_name}-0")
        asgs = network_interface[:application_security_groups]
        asg_names = []
        asgs.each do |asg|
          asg_names.push(asg[:name])
        end
        expect(asg_names).to eq([@application_security_group])
      end
    end
  end

  def vm_lifecycle
    logger.info("Creating VM with stemcell_id='#{@stemcell_id}'")
    instance_id = cpi.create_vm(
      SecureRandom.uuid,
      @stemcell_id,
      vm_properties,
      network_spec
    )
    expect(instance_id).to be

    logger.info("Checking VM existence instance_id='#{instance_id}'")
    expect(cpi.has_vm?(instance_id)).to be(true)

    logger.info("Setting VM metadata instance_id='#{instance_id}'")
    cpi.set_vm_metadata(instance_id, vm_metadata)

    cpi.reboot_vm(instance_id)

    yield(instance_id) if block_given?
  ensure
    cpi.delete_vm(instance_id) unless instance_id.nil?
  end
end
