module Bosh::AzureCloud
  class StorageAccountManager
    include Helpers

    def initialize(azure_properties, blob_manager, disk_manager, azure_client2)
      @azure_properties = azure_properties
      @blob_manager  = blob_manager
      @disk_manager  = disk_manager
      @azure_client2 = azure_client2
      @logger = Bosh::Clouds::Config.logger

      @default_storage_account_name = nil
      @default_storage_account = nil
    end

    def create_storage_account(storage_account_name, storage_account_location, storage_account_type, tags = {})
      @logger.debug("create_storage_account(#{storage_account_name}, #{storage_account_location}, #{storage_account_type}, #{tags})")

      cloud_error("missing required cloud property `storage_account_type' to create the storage account `#{storage_account_name}'.") if storage_account_type.nil?

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
          created = storage_account[:provisioning_state] == PROVISIONING_STATE_SUCCEEDED
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
          error_msg += "But it failed to prepare the containers `#{DISK_CONTAINER}' and `#{STEMCELL_CONTAINER}'.\n"
          error_msg += "You need to manually create them if they don't exist,\n"
          error_msg += "and set the public access level of the container `#{STEMCELL_CONTAINER}' to `#{PUBLIC_ACCESS_LEVEL_BLOB}'.\n"
        end
        error_msg += "Error: #{e.inspect}\n#{e.backtrace.join("\n")}"
        cloud_error(error_msg)
      end
    end

    def get_storage_account_from_resource_pool(resource_pool)
      @logger.debug("get_storage_account_from_resource_pool(#{resource_pool})")

      # If storage_account_name is not specified in resource_pool, use the default storage account in global configurations
      storage_account_name = @default_storage_account_name
      unless resource_pool['storage_account_name'].nil?
        if resource_pool['storage_account_name'].include?('*')
          ret = resource_pool['storage_account_name'].match('^\*{1}[a-z0-9]+\*{1}$')
          cloud_error("get_storage_account_from_resource_pool - storage_account_name in resource_pool is invalid. It should be '*keyword*' (keyword only contains numbers and lower-case letters) if it is a pattern.") if ret.nil?

          # Users could use *xxx* as the pattern
          # Users could specify the maximum disk numbers storage_account_max_disk_number in one storage account. Default is 30.
          # CPI uses the pattern to filter all storage accounts under the default resource group and
          # then randomly select an available storage account in which the disk numbers under the container `bosh'
          # is not more than the limitation.
          pattern = resource_pool['storage_account_name']
          storage_account_max_disk_number = resource_pool.fetch('storage_account_max_disk_number', 30)
          @logger.debug("get_storage_account_from_resource_pool - Picking one available storage account by pattern `#{pattern}', max disk number `#{storage_account_max_disk_number}'")

          # Remove * in the pattern
          pattern = pattern[1..-2]
          storage_accounts = @azure_client2.list_storage_accounts().select{ |s| s[:name] =~ /^.*#{pattern}.*$/ }
          @logger.debug("get_storage_account_from_resource_pool - Pick all storage accounts by pattern:\n#{storage_accounts.inspect}")

          result = []
          # Randomaly pick one storage account
          storage_accounts.shuffle!
          storage_accounts.each do |storage_account|
            disks = @disk_manager.list_disks(storage_account[:name])
            if disks.size <= storage_account_max_disk_number
              @logger.debug("get_storage_account_from_resource_pool - Pick the available storage account `#{storage_account[:name]}', current disk numbers: `#{disks.size}'")
              return storage_account
            else
              result << {
                :name => storage_account[:name],
                :disk_count => disks.size
              }
            end
          end

          cloud_error("get_storage_account_from_resource_pool - Cannot find an available storage account.\n#{result.inspect}")
        else
          storage_account_name = resource_pool['storage_account_name']
          storage_account = @azure_client2.get_storage_account_by_name(storage_account_name)
          # Create the storage account automatically if the storage account in resource_pool does not exist
          if storage_account.nil?
            create_storage_account(storage_account_name, resource_pool['storage_account_location'], resource_pool['storage_account_type'])
          end
        end
      end

      @logger.debug("get_storage_account_from_resource_pool: use the storage account `#{storage_account_name}'")
      storage_account = @azure_client2.get_storage_account_by_name(storage_account_name) if storage_account.nil?
      storage_account
    end

    def default_storage_account_name()
      return @default_storage_account_name unless @default_storage_account_name.nil?

      if @azure_properties.has_key?('storage_account_name')
        @default_storage_account_name = @azure_properties['storage_account_name']
        return @default_storage_account_name
      end

      @default_storage_account_name = default_storage_account[:name]
    end

    def default_storage_account()
      return @default_storage_account unless @default_storage_account.nil?

      storage_account_name = nil
      if @azure_properties.has_key?('storage_account_name')
        storage_account_name = @azure_properties['storage_account_name']
        @logger.debug("The default storage account is `#{storage_account_name}'")
        @default_storage_account = @azure_client2.get_storage_account_by_name(storage_account_name)
        return @default_storage_account
      end

      @logger.debug("The default storage account is not specified in global settings. Will look for an existing storage account.")
      storage_accounts = @azure_client2.list_storage_accounts()
      location = @azure_client2.get_resource_group()[:location]
      storage_account = storage_accounts.find{ |s|
        s[:location] == location && is_stemcell_storage_account?(s[:tags])
      }
      unless storage_account.nil?
        @logger.debug("The default storage account is `#{storage_account[:name]}'")
        @default_storage_account = storage_account
        return @default_storage_account
      end

      @logger.debug("Cannot find a storage account with the tags `#{STEMCELL_STORAGE_ACCOUNT_TAGS}' in the location `#{location}'")
      @logger.debug("Will look for a storage account without the tags `#{STEMCELL_STORAGE_ACCOUNT_TAGS}' in the location `#{location}'")
      storage_account = storage_accounts.find{ |s|
        s[:location] == location
      }
      unless storage_account.nil?
        storage_account_name = storage_account[:name]
        @logger.debug("Use an exisiting storage account `#{storage_account_name}' as the default storage account")
        @logger.debug("Set the tags `#{STEMCELL_STORAGE_ACCOUNT_TAGS}' for the storage account `#{storage_account_name}'")
        @azure_client2.update_tags_of_storage_account(storage_account_name, STEMCELL_STORAGE_ACCOUNT_TAGS)
        @default_storage_account = storage_account
        return @default_storage_account
      end

      @logger.debug("Cannot find any existing storage account in the location `#{location}'")
      storage_account_name = "cpi#{SecureRandom.hex(10)}"
      @logger.debug("Creating a storage account `#{storage_account_name}' with the tags `#{STEMCELL_STORAGE_ACCOUNT_TAGS}' in the location `#{location}'")
      create_storage_account(storage_account_name, location, 'Standard_LRS', STEMCELL_STORAGE_ACCOUNT_TAGS)
      @logger.debug("The default storage account is `#{storage_account_name}'")
      @default_storage_account = @azure_client2.get_storage_account_by_name(storage_account_name)
    end
  end
end
