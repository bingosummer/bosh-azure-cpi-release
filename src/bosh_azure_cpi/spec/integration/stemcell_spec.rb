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
  end

  let(:azure_environment)          { ENV.fetch('BOSH_AZURE_ENVIRONMENT', 'AzureCloud') }
  let(:storage_account_name)       { ENV.fetch('BOSH_AZURE_STORAGE_ACCOUNT_NAME', nil) }
  let(:use_managed_disks)          { ENV.fetch('BOSH_AZURE_USE_MANAGED_DISKS', false).to_s == 'true' }
  let(:image_path)                 { ENV.fetch('BOSH_AZURE_STEMCELL_PATH', '/tmp/image') }

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

  context '#stemcell' do
    context 'with heavy stemcell', heavy_stemcell: true do
      it 'should create/delete the stemcell' do
        heavy_stemcell_id = cpi.create_stemcell(image_path, {})
        expect(heavy_stemcell_id).not_to be_nil
        cpi.delete_stemcell(heavy_stemcell_id)
      end
    end

    context 'with light stemcell', light_stemcell: true do
      let(:windows_light_stemcell_sku)     { ENV.fetch('BOSH_AZURE_WINDOWS_LIGHT_STEMCELL_SKU', '2012r2') }
      let(:windows_light_stemcell_version) { ENV.fetch('BOSH_AZURE_WINDOWS_LIGHT_STEMCELL_VERSION', '1200.7.001001') }
      let(:stemcell_properties) do
        {
          'infrastructure' => 'azure',
          'os_type' => 'windows',
          'image' => {
            'offer'     => 'bosh-windows-server',
            'publisher' => 'pivotal',
            'sku'       => windows_light_stemcell_sku,
            'version'   => windows_light_stemcell_version
          }
        }
      end
      it 'should create/delete the stemcell' do
        light_stemcell_id = cpi.create_stemcell(image_path, stemcell_properties)
        expect(light_stemcell_id).not_to be_nil
        cpi.delete_stemcell(light_stemcell_id)
      end
    end
  end
end
