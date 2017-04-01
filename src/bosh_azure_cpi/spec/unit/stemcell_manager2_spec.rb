require 'spec_helper'

describe Bosh::AzureCloud::StemcellManager2 do
  let(:blob_manager) { instance_double(Bosh::AzureCloud::BlobManager) }
  let(:table_manager) { instance_double(Bosh::AzureCloud::TableManager) }
  let(:storage_account_manager) { instance_double(Bosh::AzureCloud::StorageAccountManager) }
  let(:client2) { instance_double(Bosh::AzureCloud::AzureClient2) }
  let(:stemcell_manager2) { Bosh::AzureCloud::StemcellManager2.new(blob_manager, table_manager, storage_account_manager, client2) }
  let(:stemcell_name) { "fake-stemcell-name" }

  before do
    allow(storage_account_manager).to receive(:default_storage_account_name).
      and_return(MOCK_DEFAULT_STORAGE_ACCOUNT_NAME)
  end

  describe "#delete_stemcell" do
    let(:user_images) {
      [
        { :name => "#{stemcell_name}-postfix1" },
        { :name => "#{stemcell_name}-postfix2" },
        { :name => "prefix-#{stemcell_name}" },
        { :name => "prefix-#{stemcell_name}-postfix" }
      ]
    }

    let(:storage_accounts) {
      [
        { :name => "foo" },
        { :name => "bar" }
      ]
    }

    let(:entities) {
      [
        {
          'PartitionKey' => stemcell_name,
          'RowKey'       => 'fake-storage-account-name',
          'Status'       => 'success',
          'Timestamp'    => Time.now
        }
      ]
    }

    before do
      allow(client2).to receive(:list_user_images).
        and_return(user_images)
      allow(client2).to receive(:list_storage_accounts).
        and_return(storage_accounts)
      allow(table_manager).to receive(:has_table?).
        and_return(true)
      allow(blob_manager).to receive(:get_blob_properties).
        and_return({"foo" => "bar"}) # The blob properties are not nil, which means the stemcell exists
      allow(table_manager).to receive(:query_entities).
        and_return(entities)
    end

    it "deletes the stemcell in default storage account" do
      # Delete the user images whose prefix is the stemcell_name
      expect(client2).to receive(:delete_user_image).
        with("#{stemcell_name}-postfix1").once
      expect(client2).to receive(:delete_user_image).
        with("#{stemcell_name}-postfix2").once

      # Delete all stemcells with the given stemcell name in all storage accounts
      expect(blob_manager).to receive(:delete_blob).twice

      # Delete all records whose PartitionKey is the given stemcell name
      allow(table_manager).to receive(:delete_entity)

      stemcell_manager2.delete_stemcell(stemcell_name)
    end
  end

  describe "#has_stemcell?" do
    context "when the storage account has the stemcell" do
      it "should return true" do
        expect(blob_manager).to receive(:get_blob_properties).
          and_return({})

        expect(
          stemcell_manager2.has_stemcell?(MOCK_DEFAULT_STORAGE_ACCOUNT_NAME, stemcell_name)
        ).to be(true)
      end
    end

    context "when the storage account doesn't have the stemcell" do
      it "should return false" do
        expect(blob_manager).to receive(:get_blob_properties).
          and_return(nil)

        expect(
          stemcell_manager2.has_stemcell?(MOCK_DEFAULT_STORAGE_ACCOUNT_NAME, stemcell_name)
        ).to be(false)
      end
    end
  end

  describe "#get_user_image_info" do
    let(:storage_account_type) { "Standard_LRS" }
    let(:location) { "SoutheastAsia" }
    let(:user_image_name) { "#{stemcell_name}-#{storage_account_type}-#{location}" }
    let(:user_image_id) { "fake-user-image-id" }
    let(:tags) {
      {
        "foo" => "bar"
      }
    }
    let(:user_image) {
      {
        :id => user_image_id,
        :tags => tags
      }
    }

    context "when the user image already exists" do
      before do
        allow(client2).to receive(:get_user_image_by_name).
          with(user_image_name).
          and_return(user_image)
      end

      it "should return the user image information" do
        expect(storage_account_manager).not_to receive(:default_storage_account)
        stemcell_info = stemcell_manager2.get_user_image_info(stemcell_name, storage_account_type, location)
        expect(stemcell_info.uri).to eq(user_image_id)
        expect(stemcell_info.metadata).to eq(tags)
      end
    end

    context "when the user image doesn't exist" do
      context "when the stemcell doesn't exist in the default storage account" do
        let(:default_storage_account) {
          {
            :name => MOCK_DEFAULT_STORAGE_ACCOUNT_NAME
          }
        }

        before do
          allow(client2).to receive(:get_user_image_by_name).
            with(user_image_name).
            and_return(nil)
          allow(storage_account_manager).to receive(:default_storage_account).
            and_return(default_storage_account)
          allow(blob_manager).to receive(:get_blob_properties).
            and_return(nil) # The blob properties are nil, which means the stemcell doesn't exist
        end

        it "should raise an error" do
          expect{
            stemcell_manager2.get_user_image_info(stemcell_name, storage_account_type, location)
          }.to raise_error /Failed to get user image for the stemcell `#{stemcell_name}'/
        end
      end

      context "when the stemcell exists in the default storage account" do
        let(:stemcell_container) { 'stemcell' }
        let(:stemcell_blob_uri) { 'fake-blob-url' }
        let(:stemcell_blob_metadata) { { "foo" => "bar" } }
        let(:user_image) {
          {
            :id => user_image_id,
            :tags => tags,
            :provisioning_state => "Succeeded"
          }
        }

        before do
          allow(client2).to receive(:get_user_image_by_name).
            with(user_image_name).
            and_return(nil, user_image) # The first return value nil means the user image doesn't exist, the second one user_image is returned after the image is created.
          allow(blob_manager).to receive(:get_blob_properties).
            with(MOCK_DEFAULT_STORAGE_ACCOUNT_NAME, stemcell_container, "#{stemcell_name}.vhd").
            and_return({"foo" => "bar"}) # The stemcell exists in the default storage account
          allow(client2).to receive(:create_user_image)
        end

        context "when the location of the default storage account is the targeted location" do
          let(:default_storage_account) {
            {
              :name => MOCK_DEFAULT_STORAGE_ACCOUNT_NAME,
              :location => location
            }
          }
          before do
            allow(storage_account_manager).to receive(:default_storage_account).
              and_return(default_storage_account)
            allow(blob_manager).to receive(:get_blob_uri).
              with(MOCK_DEFAULT_STORAGE_ACCOUNT_NAME, stemcell_container, "#{stemcell_name}.vhd").
              and_return(stemcell_blob_uri)
            allow(blob_manager).to receive(:get_blob_metadata).
              with(MOCK_DEFAULT_STORAGE_ACCOUNT_NAME, stemcell_container, "#{stemcell_name}.vhd").
              and_return(stemcell_blob_metadata)
          end

          let(:lock_creating_user_image) { instance_double(Bosh::AzureCloud::Helpers::FileMutex) }
          before do
            allow(Bosh::AzureCloud::Helpers::FileMutex).to receive(:new).and_return(lock_creating_user_image)
            allow(lock_creating_user_image).to receive(:lock).and_return(true)
            allow(lock_creating_user_image).to receive(:unlock)
          end

          it "should get the stemcell from the default storage account, create a new user image and return the user image information" do
            expect(client2).not_to receive(:list_storage_accounts)
            stemcell_info = stemcell_manager2.get_user_image_info(stemcell_name, storage_account_type, location)
            expect(stemcell_info.uri).to eq(user_image_id)
            expect(stemcell_info.metadata).to eq(tags)
          end
        end

        context "when the location of the default storage account is not the targeted location" do
          let(:default_storage_account) {
            {
              :name => MOCK_DEFAULT_STORAGE_ACCOUNT_NAME,
              :location => "#{location}-different"
            }
          }
          before do
            allow(storage_account_manager).to receive(:default_storage_account).
              and_return(default_storage_account)
          end

          context "when the storage account with tags exists in the specified location" do
            let(:existing_storage_account_name) { "existing-storage-account-name-other-than-default-storage-account" }
            let(:storage_accounts) {
              [
                {
                  :name => existing_storage_account_name,
                  :location => location,
                  :tags => STEMCELL_STORAGE_ACCOUNT_TAGS
                }
              ]
            }
            before do
              allow(client2).to receive(:list_storage_accounts).and_return(storage_accounts)
              # The following two allows are for get_stemcell_info of stemcell_manager.rb
              allow(blob_manager).to receive(:get_blob_uri).
                with(existing_storage_account_name, stemcell_container, "#{stemcell_name}.vhd").
                and_return(stemcell_blob_uri)
              allow(blob_manager).to receive(:get_blob_metadata).
                with(existing_storage_account_name, stemcell_container, "#{stemcell_name}.vhd").
                and_return(stemcell_blob_metadata)
            end

            let(:lock_creating_storage_account) { instance_double(Bosh::AzureCloud::Helpers::FileMutex) }
            let(:lock_copy_blob) { instance_double(Bosh::AzureCloud::Helpers::FileMutex) }
            before do
              allow(Bosh::AzureCloud::Helpers::FileMutex).to receive(:new).and_return(lock_creating_storage_account, lock_copy_blob)
              allow(lock_creating_storage_account).to receive(:lock).and_return(true)
              allow(lock_creating_storage_account).to receive(:unlock)
            end

            context "when the lock of copying blob is not acquired" do
              before do
                allow(lock_copy_blob).to receive(:lock).and_return(false)
                allow(lock_copy_blob).to receive(:expired).and_return("fake-expired-value")
              end

              context "when copying blob timeouts" do
                before do
                  allow(lock_copy_blob).to receive(:wait).and_raise(Bosh::AzureCloud::Helpers::LockTimeoutError)
                end

                it "should raise a timeout error" do
                  expect(blob_manager).not_to receive(:get_blob_uri)
                  expect(blob_manager).not_to receive(:copy_blob)
                  expect(File).to receive(:open).with(Bosh::AzureCloud::Helpers::CPI_LOCK_DELETE, "wb")
                  expect {
                    stemcell_manager2.get_user_image_info(stemcell_name, storage_account_type, location)
                  }.to raise_error /get_user_image: Failed to finish the copying process of the stemcell/
                end
              end

              context "when copying blob finishes before it timeouts" do
                before do
                  allow(lock_copy_blob).to receive(:wait)
                end

                it "should create a new user image and return the user image information" do
                  expect(blob_manager).not_to receive(:copy_blob)
                  stemcell_info = stemcell_manager2.get_user_image_info(stemcell_name, storage_account_type, location)
                  expect(stemcell_info.uri).to eq(user_image_id)
                  expect(stemcell_info.metadata).to eq(tags)
                end
              end
            end

            context "when the lock of copying blob is acquired" do
              before do
                allow(lock_copy_blob).to receive(:lock).and_return(true)
              end

              context "when the stemcell exists in the exising storage account" do
                before do
                  allow(blob_manager).to receive(:get_blob_properties).
                    with(existing_storage_account_name, stemcell_container, "#{stemcell_name}.vhd").
                    and_return({"foo"=>"bar"}) # The stemcell exists in the existing storage account
                  allow(lock_copy_blob).to receive(:unlock)
                end

                it "should create a new user image and return the user image information" do
                  expect(blob_manager).not_to receive(:get_blob_uri).
                    with(MOCK_DEFAULT_STORAGE_ACCOUNT_NAME, stemcell_container, "#{stemcell_name}.vhd")
                  expect(blob_manager).not_to receive(:copy_blob)
                  stemcell_info = stemcell_manager2.get_user_image_info(stemcell_name, storage_account_type, location)
                  expect(stemcell_info.uri).to eq(user_image_id)
                  expect(stemcell_info.metadata).to eq(tags)
                end
              end

              context "when the stemcell doesn't exist in the exising storage account" do
                before do
                  allow(blob_manager).to receive(:get_blob_properties).
                    with(existing_storage_account_name, stemcell_container, "#{stemcell_name}.vhd").
                    and_return(nil) # The stemcell doesn't exist in the existing storage account
                end

                context "when copying blob is successful" do
                  before do
                    allow(lock_copy_blob).to receive(:update)
                    allow(lock_copy_blob).to receive(:unlock)
                  end

                  it "should copy the stemcell from default storage account to an existing storage account, create a new user image and return the user image information" do
                    expect(blob_manager).to receive(:get_blob_uri).
                      with(MOCK_DEFAULT_STORAGE_ACCOUNT_NAME, stemcell_container, "#{stemcell_name}.vhd").
                      and_return(stemcell_blob_uri)
                    expect(blob_manager).to receive(:copy_blob).
                      with(existing_storage_account_name, stemcell_container, "#{stemcell_name}.vhd", stemcell_blob_uri)
                    stemcell_info = stemcell_manager2.get_user_image_info(stemcell_name, storage_account_type, location)
                    expect(stemcell_info.uri).to eq(user_image_id)
                    expect(stemcell_info.metadata).to eq(tags)
                  end
                end

                context "when copying blob raises an error" do
                  before do
                    allow(blob_manager).to receive(:get_blob_uri).
                      with(MOCK_DEFAULT_STORAGE_ACCOUNT_NAME, stemcell_container, "#{stemcell_name}.vhd").
                      and_return(stemcell_blob_uri)
                    expect(blob_manager).to receive(:copy_blob).
                      with(existing_storage_account_name, stemcell_container, "#{stemcell_name}.vhd", stemcell_blob_uri).
                      and_raise("Error when copying blobs")
                  end

                  it "should raise an error" do
                    expect(lock_copy_blob).not_to receive(:unlock)
                    expect {
                      stemcell_manager2.get_user_image_info(stemcell_name, storage_account_type, location)
                    }.to raise_error /Error when copying blobs/
                  end
                end
              end
            end
          end

          context "when the storage account with tags doesn't exist in the specified location" do
            context "when it fails to create the new storage account" do
              let(:lock_creating_storage_account) { instance_double(Bosh::AzureCloud::Helpers::FileMutex) }
              before do
                allow(Bosh::AzureCloud::Helpers::FileMutex).to receive(:new).with("bosh-lock-create-storage-account-#{location}", anything).
                  and_return(lock_creating_storage_account)
              end

              context "when an error is thrown when creating the new storage account" do
                before do
                  allow(lock_creating_storage_account).to receive(:lock).and_return(true)
                  allow(client2).to receive(:list_storage_accounts).and_return([])
                  allow(storage_account_manager).to receive(:generate_storage_account_name)
                  allow(storage_account_manager).to receive(:create_storage_account).
                    and_raise("Error when creating storage account")
                end

                it "raise an error" do
                  expect(lock_creating_storage_account).not_to receive(:unlock)
                  expect {
                    stemcell_manager2.get_user_image_info(stemcell_name, storage_account_type, location)
                  }.to raise_error /Error when creating storage account/
                end
              end

              context "when it timeouts to create the new storage account" do
                before do
                  allow(lock_creating_storage_account).to receive(:lock).and_return(false)
                  allow(lock_creating_storage_account).to receive(:wait).
                    and_raise(Bosh::AzureCloud::Helpers::LockTimeoutError)
                  allow(lock_creating_storage_account).to receive(:expired).and_return("fake-expired-value")
                end

                it "raise an error" do
                  expect(lock_creating_storage_account).not_to receive(:unlock)
                  expect(File).to receive(:open).with(Bosh::AzureCloud::Helpers::CPI_LOCK_DELETE, "wb")
                  expect {
                    stemcell_manager2.get_user_image_info(stemcell_name, storage_account_type, location)
                  }.to raise_error /Failed to finish the creation of the storage account/
                end
              end
            end

            context "when it creates the new storage account successfully, and copies the stemcell from default storage account to the new storage account" do
              let(:new_storage_account_name) { "54657da5936725e199fd616e" }
              let(:storage_account) {
                [
                  {
                    :name => new_storage_account_name,
                    :location => location,
                    :tags => STEMCELL_STORAGE_ACCOUNT_TAGS
                  }
                ]
              }
              let(:lock_creating_storage_account) { instance_double(Bosh::AzureCloud::Helpers::FileMutex) }
              let(:lock_copy_blob) { instance_double(Bosh::AzureCloud::Helpers::FileMutex) }

              before do
                allow(Bosh::AzureCloud::Helpers::FileMutex).to receive(:new).and_return(lock_creating_storage_account, lock_copy_blob)

                # Create a new storage account
                allow(lock_creating_storage_account).to receive(:lock).and_return(true)
                allow(lock_creating_storage_account).to receive(:unlock)
                allow(storage_account_manager).to receive(:generate_storage_account_name).and_return(new_storage_account_name)
                allow(storage_account_manager).to receive(:create_storage_account).
                  with(new_storage_account_name, storage_account_type, location, STEMCELL_STORAGE_ACCOUNT_TAGS)
                allow(client2).to receive(:list_storage_accounts).and_return([], storage_account) # The first return value nil means the storage account doesn't exist, the second value is returned after the storage account is created.

                # The following two allows are for get_stemcell_info of stemcell_manager.rb
                allow(blob_manager).to receive(:get_blob_uri).
                  with(new_storage_account_name, stemcell_container, "#{stemcell_name}.vhd").
                  and_return(stemcell_blob_uri)
                allow(blob_manager).to receive(:get_blob_metadata).
                  with(new_storage_account_name, stemcell_container, "#{stemcell_name}.vhd").
                  and_return(stemcell_blob_metadata)
                allow(blob_manager).to receive(:get_blob_properties).
                  with(new_storage_account_name, stemcell_container, "#{stemcell_name}.vhd").
                  and_return(nil) # The stemcell doesn't exist in the new storage account

                # Copy blob
                allow(lock_copy_blob).to receive(:lock).and_return(true)
                allow(lock_copy_blob).to receive(:unlock)
                allow(blob_manager).to receive(:get_blob_uri).
                  with(MOCK_DEFAULT_STORAGE_ACCOUNT_NAME, stemcell_container, "#{stemcell_name}.vhd").
                  and_return(stemcell_blob_uri)
                allow(blob_manager).to receive(:copy_blob).
                  with(new_storage_account_name, stemcell_container, "#{stemcell_name}.vhd", stemcell_blob_uri)
              end

              it "should create a new user image and return the user image information" do
                stemcell_info = stemcell_manager2.get_user_image_info(stemcell_name, storage_account_type, location)
                expect(stemcell_info.uri).to eq(user_image_id)
                expect(stemcell_info.metadata).to eq(tags)
              end
            end
          end
        end

        context "Check whether user image is created" do
          let(:default_storage_account) {
            {
              :name => MOCK_DEFAULT_STORAGE_ACCOUNT_NAME,
              :location => location
            }
          }
          before do
            allow(client2).to receive(:create_user_image)
            allow(storage_account_manager).to receive(:default_storage_account).
              and_return(default_storage_account)
            allow(blob_manager).to receive(:get_blob_properties).
              with(MOCK_DEFAULT_STORAGE_ACCOUNT_NAME, stemcell_container, "#{stemcell_name}.vhd").
              and_return({"foo" => "bar"}) # The stemcell exists in the default storage account
            allow(blob_manager).to receive(:get_blob_uri).
              with(MOCK_DEFAULT_STORAGE_ACCOUNT_NAME, stemcell_container, "#{stemcell_name}.vhd").
              and_return(stemcell_blob_uri)
            allow(blob_manager).to receive(:get_blob_metadata).
              with(MOCK_DEFAULT_STORAGE_ACCOUNT_NAME, stemcell_container, "#{stemcell_name}.vhd").
              and_return(stemcell_blob_metadata)
          end

          context "when user image can't be found" do
            before do
              allow(client2).to receive(:get_user_image_by_name).
                with(user_image_name).
                and_return(nil, nil) # The first return value nil means the user image doesn't exist, the others are returned after the image is created.
            end

            let(:lock_creating_user_image) { instance_double(Bosh::AzureCloud::Helpers::FileMutex) }
            before do
              allow(Bosh::AzureCloud::Helpers::FileMutex).to receive(:new).and_return(lock_creating_user_image)
              allow(lock_creating_user_image).to receive(:lock).and_return(true)
              allow(lock_creating_user_image).to receive(:unlock)
            end

            it "should raise an error" do
              expect {
                stemcell_manager2.get_user_image_info(stemcell_name, storage_account_type, location)
              }.to raise_error(/get_user_image: Can not find a user image with the name `#{user_image_name}'/)
            end
          end

          context "when the user image is created successfully" do
            let(:user_image) {
              {
                :id => user_image_id,
                :tags => tags,
                :provisioning_state => "Succeeded"
              }
            }

            before do
              allow(client2).to receive(:get_user_image_by_name).
                with(user_image_name).
                and_return(user_image)
            end

            it "should return the new user image" do
              stemcell_info = stemcell_manager2.get_user_image_info(stemcell_name, storage_account_type, location)
              expect(stemcell_info.uri).to eq(user_image_id)
              expect(stemcell_info.metadata).to eq(tags)
            end
          end
        end
      end
    end
  end
end
