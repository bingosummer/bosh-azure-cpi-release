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
  end

  let(:azure_environment)          { ENV.fetch('BOSH_AZURE_ENVIRONMENT', 'AzureCloud') }
  let(:location)                   { ENV.fetch('BOSH_AZURE_LOCATION', 'westcentralus') }
  let(:storage_account_name)       { ENV.fetch('BOSH_AZURE_STORAGE_ACCOUNT_NAME', nil) }
  let(:extra_storage_account_name) { ENV.fetch('BOSH_AZURE_EXTRA_STORAGE_ACCOUNT_NAME', nil) }
  let(:use_managed_disks)          { ENV.fetch('BOSH_AZURE_USE_MANAGED_DISKS', false).to_s == 'true' }
  let(:vnet_name)                  { ENV.fetch('BOSH_AZURE_VNET_NAME', 'boshvnet-crp') }
  let(:subnet_name)                { ENV.fetch('BOSH_AZURE_DYNAMIC_SUBNET_NAME', 'BOSH1') }
  let(:second_subnet_name)         { ENV.fetch('BOSH_AZURE_MANUAL_SUBNET_2_NAME', 'BOSH2') }
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

  subject(:cpi_with_location) do
    cloud_options_with_location = cloud_options.dup
    cloud_options_with_location['azure']['storage_account_name'] = storage_account_name unless storage_account_name.nil?
    cloud_options_with_location['azure']['use_managed_disks'] = use_managed_disks
    cloud_options_with_location['azure']['location'] = location
    described_class.new(cloud_options_with_location)
  end

  subject(:cpi_without_default_nsg) do
    cloud_options_without_default_nsg = cloud_options.dup
    cloud_options_without_default_nsg['azure']['storage_account_name'] = storage_account_name unless storage_account_name.nil?
    cloud_options_without_default_nsg['azure']['use_managed_disks'] = use_managed_disks
    cloud_options_without_default_nsg['azure']['default_security_group'] = nil
    described_class.new(cloud_options_without_default_nsg)
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

  context '#calculate_vm_cloud_properties' do
    let(:vm_resources) do
      {
        'cpu' => 2,
        'ram' => 4096,
        'ephemeral_disk_size' => 32 * 1024
      }
    end
    it 'should return Azure specific cloud properties' do
      expect(cpi_with_location.calculate_vm_cloud_properties(vm_resources)).to eq(
        'instance_type' => 'Standard_F2',
        'ephemeral_disk' => {
          'size' => 32 * 1024
        }
      )
    end
  end

  context 'when default_security_group is not specified' do
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

    it 'should exercise the vm lifecycle' do
      begin
        logger.info("Creating VM with stemcell_id='#{@stemcell_id}'")
        instance_id = cpi_without_default_nsg.create_vm(
          SecureRandom.uuid,
          @stemcell_id,
          vm_properties,
          network_spec
        )
        expect(instance_id).to be

        instance_id_obj = Bosh::AzureCloud::InstanceId.parse(instance_id, azure_config)
        network_interface = cpi_without_default_nsg.azure_client.get_network_interface_by_name(@default_resource_group_name, "#{instance_id_obj.vm_name}-0")
        nsg = network_interface[:network_security_group]
        expect(nsg).to be_nil
      ensure
        cpi_without_default_nsg.delete_vm(instance_id) unless instance_id.nil?
      end
    end
  end

  context 'multiple nics' do
    let(:instance_type) { 'Standard_D2_v2' }
    let(:network_spec) do
      {
        'network_a' => {
          'type' => 'dynamic',
          'default' => %w[dns gateway],
          'cloud_properties' => {
            'virtual_network_name' => vnet_name,
            'subnet_name' => subnet_name
          }
        },
        'network_b' => {
          'type' => 'manual',
          'ip' => "10.0.1.#{Random.rand(10..99)}",
          'cloud_properties' => {
            'virtual_network_name' => vnet_name,
            'subnet_name' => second_subnet_name
          }
        },
        'network_c' => {
          'type' => 'vip',
          'ip' => @primary_public_ip
        }
      }
    end

    it 'should exercise the vm lifecycle' do
      vm_lifecycle
    end
  end

  context 'when assigning dynamic public IP to VM' do
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
        'assign_dynamic_public_ip' => true
      }
    end

    it 'should exercise the vm lifecycle' do
      vm_lifecycle
    end
  end

  context 'when assigning a different storage account to VM', unmanaged_disks: true do
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
        'storage_account_name' => extra_storage_account_name
      }
    end

    it 'should exercise the vm lifecycle' do
      lifecycles = []
      3.times do |i|
        lifecycles[i] = Thread.new do
          vm_lifecycle
        end
      end
      lifecycles.each(&:join)
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
