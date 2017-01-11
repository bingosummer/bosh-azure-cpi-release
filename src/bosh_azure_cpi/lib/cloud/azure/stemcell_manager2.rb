module Bosh::AzureCloud
  class StemcellManager2
    include Bosh::Exec
    include Helpers

    def initialize(azure_properties, blob_manager, table_manager, stemcell_manager, storage_account_manager, azure_client2)
      @azure_properties = azure_properties
      @blob_manager  = blob_manager
      @table_manager = table_manager
      @stemcell_manager = stemcell_manager
      @storage_account_manager = storage_account_manager
      @azure_client2 = azure_client2
      @logger = Bosh::Clouds::Config.logger
    end

    def delete_stemcell(name)
      @logger.info("delete_stemcell(#{name})")

      user_images = @azure_client2.list_user_images().select{ |item| item[:name] =~ /^#{name}/ }
      user_images.each do |user_image|
        user_image_name = user_image[:name]
        @logger.info("Delete user image `#{user_image_name}'")
        @azure_client2.delete_user_image(user_image_name)
      end

      # Delete all stemcells with the given stemcell name in all storage accounts
      storage_accounts = @azure_client2.list_storage_accounts()
      storage_accounts.each do |storage_account|
        storage_account_name = storage_account[:name]
        @logger.info("Delete stemcell `#{name}' in the storage `#{storage_account_name}'")
        @blob_manager.delete_blob(storage_account_name, STEMCELL_CONTAINER, "#{name}.vhd") if has_stemcell?(storage_account_name, name)
      end

      # Delete all records whose PartitionKey is the given stemcell name
      if @table_manager.has_table?(STEMCELL_TABLE)
        options = {
          :filter => "PartitionKey eq '#{name}'"
        }
        entities = @table_manager.query_entities(STEMCELL_TABLE, options)
        entities.each do |entity|
          storage_account_name = entity['RowKey']
          @logger.info("Delete records `#{entity['RowKey']}' whose PartitionKey is `#{entity['PartitionKey']}'")
          @table_manager.delete_entity(STEMCELL_TABLE, entity['PartitionKey'], entity['RowKey'])
        end
      end
    end

    def create_stemcell(image_path, cloud_properties)
      @logger.info("create_stemcell(#{image_path}, #{cloud_properties})")

      storage_account_name = @storage_account_manager.default_storage_account_name
      stemcell_name = nil
      Dir.mktmpdir('sc-') do |tmp_dir|
        @logger.info("Unpacking image: #{image_path}")
        run_command("tar -zxf #{image_path} -C #{tmp_dir}")
        @logger.info("Start to upload VHD")
        stemcell_name = "#{STEMCELL_PREFIX}-#{SecureRandom.uuid}"
        @logger.info("Upload the stemcell #{stemcell_name} to the storage account #{storage_account_name}")
        @blob_manager.create_page_blob(storage_account_name, STEMCELL_CONTAINER, "#{tmp_dir}/root.vhd", "#{stemcell_name}.vhd", cloud_properties)
      end
      stemcell_name
    end

    def has_stemcell?(storage_account_name, name)
      @logger.info("has_stemcell?(#{storage_account_name}, #{name})")
      blob_properties = @blob_manager.get_blob_properties(storage_account_name, STEMCELL_CONTAINER, "#{name}.vhd")
      !blob_properties.nil?
    end

    def get_stemcell_info(stemcell_name, storage_account_type, location)
      @logger.info("get_stemcell_info(#{stemcell_name}, #{storage_account_type}, #{location})")
      user_image = get_user_image(stemcell_name, storage_account_type, location)
      cloud_error("get_stemcell_info: Failed to get user image for the stemcell `#{stemcell_name}''") if user_image.nil?
      image_id = user_image[:id]
      metadata = user_image[:tags]
      stemcell_info = StemcellInfo.new(image_id, metadata)
    end

    private

    def run_command(command)
      output, status = Open3.capture2e(command)
      if status.exitstatus != 0
        cloud_error("'#{command}' failed with exit status=#{status.exitstatus} [#{output}]")
      end
    end

    def get_user_image(stemcell_name, storage_account_type, location)
      @logger.info("get_user_image(#{stemcell_name}, #{storage_account_type}, #{location})")
      user_image_name = "#{stemcell_name}-#{storage_account_type}-#{location}"
      user_image = @azure_client2.get_user_image_by_name(user_image_name)
      return user_image unless user_image.nil?

      default_storage_account_name = nil
      if @azure_properties.has_key?('storage_account_name')
        default_storage_account_name = @azure_properties['storage_account_name']
      else
        storage_accounts = @azure_client2.list_storage_accounts().select{ |s|
          s[:location] == @azure_client2.get_resource_group()[:location] && s[:tags] == STEMCELL_STORAGE_ACCOUNT_TAGS
        }
        cloud_error("get_user_image: No default storage account to store the stemcell `#{stemcell_name}'") if storage_accounts.empty?
        default_storage_account_name = storage_accounts[0][:name]
        @logger.info("get_user_image: Use the default storage account `#{default_storage_account_name}'")
      end
      return nil unless has_stemcell?(default_storage_account_name, stemcell_name)

      storage_account_name = nil
      default_storage_account = @azure_client2.get_storage_account_by_name(default_storage_account_name)
      if default_storage_account[:location] == location
        storage_account_name = default_storage_account_name
      else
        storage_accounts = @azure_client2.list_storage_accounts().select{ |s|
          s[:location] == location && s[:tags] == STEMCELL_STORAGE_ACCOUNT_TAGS
        }
        if storage_accounts.empty?
          storage_account_name = "cpi#{SecureRandom.hex(10)}"
          @logger.debug("get_user_image: Create a storage account `#{storage_account_name}' with the tags `#{STEMCELL_STORAGE_ACCOUNT_TAGS}' in the location `#{location}'")
          mutex = FileMutex.new('/tmp/bosh-lock-create-default-storage-account')
          mutex.synchronize do
            @storage_account_manager.create_storage_account(storage_account_name, location, 'Standard_LRS', STEMCELL_STORAGE_ACCOUNT_TAGS)
          end
          @blob_manager.prepare(storage_account_name)
        else
          storage_account_name = storage_accounts[0][:name]
        end

        mutex = FileMutex.new('/tmp/bosh-lock-stemcell', 180)
        mutex.synchronize do
          unless has_stemcell?(storage_account_name, stemcell_name)
            @logger.info("get_user_image: Copying the stemcell from the default storage account `#{default_storage_account_name}' to the storage acccount `#{storage_account_name}'")
            stemcell_source_blob_uri = @blob_manager.get_blob_uri(default_storage_account_name, STEMCELL_CONTAINER, "#{stemcell_name}.vhd")
            @blob_manager.copy_blob(storage_account_name, STEMCELL_CONTAINER, "#{stemcell_name}.vhd", stemcell_source_blob_uri) do
              mutex.update()
            end
          end
        end
      end

      stemcell_info = @stemcell_manager.get_stemcell_info(storage_account_name, stemcell_name)
      user_image_params = {
        :name                => user_image_name,
        :location            => location,
        :tags                => stemcell_info.metadata,
        :os_type             => stemcell_info.os_type,
        :source_uri          => stemcell_info.uri,
        :account_type        => 'Standard_LRS'
      }
      begin
        @azure_client2.create_user_image(user_image_params)
      rescue => e
        if e.message.include?("The request failed due to conflict with a concurrent request") || e.message.include?("Operation 'Image Update' is not supported in Preview")
          @logger.info("get_user_image: Waiting for other processes to finish creating the user image")
        else
          cloud_error("get_user_image: #{e.inspect}\n#{e.backtrace.join("\n")}")
        end
      end
      loop do
        user_image = @azure_client2.get_user_image_by_name(user_image_name)
        break if user_image && user_image[:provisioning_state] == 'Succeeded'
        sleep(5)
      end
      user_image
    end
  end
end
