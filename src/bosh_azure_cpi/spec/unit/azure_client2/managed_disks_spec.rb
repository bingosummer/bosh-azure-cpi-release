require 'spec_helper'
require 'webmock/rspec'

WebMock.disable_net_connect!(allow_localhost: true)

describe Bosh::AzureCloud::AzureClient2 do
  let(:logger) { Bosh::Clouds::Config.logger }
  let(:azure_client2) {
    Bosh::AzureCloud::AzureClient2.new(
      mock_cloud_options["properties"]["azure"],
      logger
    )
  }
  let(:subscription_id) { mock_azure_properties['subscription_id'] }
  let(:tenant_id) { mock_azure_properties['tenant_id'] }
  let(:api_version) { AZURE_API_VERSION }
  let(:api_version_compute) { AZURE_RESOURCE_PROVIDER_COMPUTE }
  let(:resource_group) { mock_azure_properties['resource_group_name'] }
  let(:request_id) { "fake-request-id" }

  let(:token_uri) { "https://login.microsoftonline.com/#{tenant_id}/oauth2/token?api-version=#{api_version}" }
  let(:operation_status_link) { "https://management.azure.com/subscriptions/#{subscription_id}/operations/#{request_id}" }

  let(:disk_name) { "fake-disk-name" }
  let(:valid_access_token) { "valid-access-token" }
  let(:expires_on) { (Time.now+1800).to_i.to_s }

  describe "#create_empty_managed_disk" do
    let(:disk_uri) { "https://management.azure.com//subscriptions/#{subscription_id}/resourceGroups/#{resource_group}/providers/Microsoft.Compute/disks/#{disk_name}?api-version=#{api_version_compute}" }

    let(:disk_params) do
      {
        :name           => disk_name,
        :location       => "b",
        :tags           => { "foo" => "bar"},
        :disk_size      => "c",
        :account_type   => "d"
      }
    end

    let(:request_body) {
      {
        :location => "b",
        :tags     => {
          :foo => "bar"
        },
        :properties => {
          :creationData => {
            :createOption => "Empty"
          },
          :accountType => "d",
          :diskSizeGB => "c"
        }
      }
    }

    it "should raise no error" do
      stub_request(:post, token_uri).to_return(
        :status => 200,
        :body => {
          "access_token" => valid_access_token,
          "expires_on" => expires_on
        }.to_json,
        :headers => {})
      stub_request(:put, disk_uri).with(body: request_body).to_return(
        :status => 200,
        :body => '',
        :headers => {
          "azure-asyncoperation" => operation_status_link
        })
      stub_request(:get, operation_status_link).to_return(
        :status => 200,
        :body => '{"status":"Succeeded"}',
        :headers => {})

      expect {
        azure_client2.create_empty_managed_disk(disk_params)
      }.not_to raise_error
    end
  end

  describe "#create_managed_disk_from_blob" do
    let(:disk_uri) { "https://management.azure.com//subscriptions/#{subscription_id}/resourceGroups/#{resource_group}/providers/Microsoft.Compute/disks/#{disk_name}?api-version=#{api_version_compute}" }

    let(:disk_params) do
      {
        :name           => disk_name,
        :location       => "b",
        :tags           => { "foo" => "bar"},
        :source_uri     => "c",
        :account_type   => "d"
      }
    end

    let(:request_body) {
      {
        :location => "b",
        :tags     => {
          :foo => "bar"
        },
        :properties => {
          :creationData => {
            :createOption => "Import",
            :sourceUri => "c"
          },
          :accountType => "d"
        }
      }
    }

    it "should raise no error" do
      stub_request(:post, token_uri).to_return(
        :status => 200,
        :body => {
          "access_token" => valid_access_token,
          "expires_on" => expires_on
        }.to_json,
        :headers => {})
      stub_request(:put, disk_uri).with(body: request_body).to_return(
        :status => 200,
        :body => '',
        :headers => {
          "azure-asyncoperation" => operation_status_link
        })
      stub_request(:get, operation_status_link).to_return(
        :status => 200,
        :body => '{"status":"Succeeded"}',
        :headers => {})

      expect {
        azure_client2.create_managed_disk_from_blob(disk_params)
      }.not_to raise_error
    end
  end

  describe "#get_managed_disk_by_name" do
    let(:disk_uri) { "https://management.azure.com//subscriptions/#{subscription_id}/resourceGroups/#{resource_group}/providers/Microsoft.Compute/disks/#{disk_name}?api-version=#{api_version_compute}" }

    let(:response_body) {
      {
        :id => "a",
        :name => "b",
        :location => "c",
        :tags     => {
          :foo => "bar"
        },
        :properties => {
          :provisioningState => "d",
          :diskSizeGB => "e",
          :accountType => "f",
          :owner => {
            :id => "a"
          },
          :faultDomain => "g",
          :storageAvailabilitySet => "h"
        }
      }
    }
    let(:disk) {
      {
        :id => "a",
        :name => "b",
        :location => "c",
        :tags     => {
          "foo" => "bar"
        },
        :provisioning_state => "d",
        :disk_size => "e",
        :account_type => "f",
        :owner_id => "a",
        :fault_domain => "g",
        :storage_avset_id => "h"
      }
    }

    it "should raise no error" do
      stub_request(:post, token_uri).to_return(
        :status => 200,
        :body => {
          "access_token" => valid_access_token,
          "expires_on" => expires_on
        }.to_json,
        :headers => {})
      stub_request(:get, disk_uri).to_return(
        :status => 200,
        :body => response_body.to_json,
        :headers => {})

      expect(
        azure_client2.get_managed_disk_by_name(disk_name)
      ).to eq(disk)
    end
  end

  describe "#list_managed_disks" do
    let(:disks_uri) { "https://management.azure.com//subscriptions/#{subscription_id}/resourceGroups/#{resource_group}/providers/Microsoft.Compute/disks?api-version=#{api_version_compute}" }

    let(:response_body) {
      {
        :value => [
          {
            :id => "a1",
            :name => "b1",
            :location => "c1",
            :tags     => {
              :foo => "bar1"
            },
            :properties => {
              :provisioningState => "d1",
              :diskSizeGB => "e1",
              :accountType => "f1",
              :owner => {
                :id => "a1"
              },
              :faultDomain => "g1",
              :storageAvailabilitySet => "h1"
            }
          },
          {
            :id => "a2",
            :name => "b2",
            :location => "c2",
            :tags     => {
              :foo => "bar2"
            },
            :properties => {
              :provisioningState => "d2",
              :diskSizeGB => "e2",
              :accountType => "f2",
              :owner => {
                :id => "a2"
              },
              :faultDomain => "g2",
              :storageAvailabilitySet => "h2"
            }
          }
        ]
      }
    }
    let(:disks) {
      [
        {
          :id => "a1",
          :name => "b1",
          :location => "c1",
          :tags     => {
            "foo" => "bar1"
          },
          :provisioning_state => "d1",
          :disk_size => "e1",
          :account_type => "f1",
          :owner_id => "a1",
          :fault_domain => "g1",
          :storage_avset_id => "h1"
        },
        {
          :id => "a2",
          :name => "b2",
          :location => "c2",
          :tags     => {
            "foo" => "bar2"
          },
          :provisioning_state => "d2",
          :disk_size => "e2",
          :account_type => "f2",
          :owner_id => "a2",
          :fault_domain => "g2",
          :storage_avset_id => "h2"
        }
      ]
    }

    it "should raise no error" do
      stub_request(:post, token_uri).to_return(
        :status => 200,
        :body => {
          "access_token" => valid_access_token,
          "expires_on" => expires_on
        }.to_json,
        :headers => {})
      stub_request(:get, disks_uri).to_return(
        :status => 200,
        :body => response_body.to_json,
        :headers => {})

      expect(
        azure_client2.list_managed_disks()
      ).to eq(disks)
    end
  end

end
