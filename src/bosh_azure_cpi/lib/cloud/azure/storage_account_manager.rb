module Bosh::AzureCloud
  class StorageAccountManager

    include Helpers

    def initialize(azure_properties, blob_manager, azure_client2)
      @azure_properties = azure_properties
      @blob_manager  = blob_manager
      @azure_client2 = azure_client2
      @logger = Bosh::Clouds::Config.logger
    end

    def create_storage_account(storage_account_name, storage_account_location, storage_account_type, tags = {})
      @logger.debug("create_storage_account(#{storage_account_name})")

      if storage_account_type.nil?
        raise Bosh::Clouds::VMCreationFailed.new(false),
          "missing required cloud property `storage_account_type' to create the storage account `#{storage_account_name}'."
      end

      created = false
      result = @azure_client2.check_storage_account_name_availability(storage_account_name)
      @logger.debug("create_storage_account - The result of check_storage_account_name_availability is #{result}")
      unless result[:available]
        if result[:reason] == 'AccountNameInvalid'
          cloud_error("The storage account name `#{storage_account_name}' is invalid. Storage account names must be between 3 and 24 characters in length and use numbers and lower-case letters only. #{result[:message]}")
        else
          # AlreadyExists
          storage_account = @azure_client2.get_storage_account_by_name(storage_account_name)
          if storage_account.nil?
            cloud_error("The storage account with the name `#{storage_account_name}' does not belong to the resource group `#{@azure_properties['resource_group_name']}'. #{result[:message]}")
          end
          # If the storage account has been created by other process, skip create.
          # If the storage account is being created by other process, continue to create.
          #    Azure can handle the scenario when multiple processes are creating a same storage account in parallel
          created = storage_account[:provisioning_state] == 'Succeeded'
        end
      end
      begin
        unless created
          unless storage_account_location.nil?
            location = storage_account_location
          else
            resource_group = @azure_client2.get_resource_group()
            location = resource_group[:location]
          end
          created = @azure_client2.create_storage_account(storage_account_name, location, storage_account_type, tags)
        end
        @blob_manager.prepare(storage_account_name)
        true
      rescue => e
        error_msg = "create_storage_account - "
        if created
          error_msg += "The storage account `#{storage_account_name}' is created successfully.\n"
          error_msg += "But it failed to create the containers bosh and stemcell.\n"
          error_msg += "You need to manually create them.\n"
        end
        error_msg += "Error: #{e.inspect}\n#{e.backtrace.join("\n")}"
        cloud_error(error_msg)
      end
    end
  end
end
