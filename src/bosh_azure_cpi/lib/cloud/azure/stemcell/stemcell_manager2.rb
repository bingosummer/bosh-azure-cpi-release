# frozen_string_literal: true

module Bosh::AzureCloud
  class StemcellManager2 < StemcellManager
    include Bosh::Exec
    include Helpers

    def initialize(blob_manager, meta_store, storage_account_manager, azure_client)
      super(blob_manager, meta_store, storage_account_manager)
      @azure_client = azure_client
    end

    def delete_stemcell(name)
      @logger.info("delete_stemcell(#{name})")

      # Both the old format and new format of managed custom image are deleted
      stemcell_uuid = name.sub("#{STEMCELL_PREFIX}-", '')
      managed_custom_images = @azure_client.list_managed_custom_images.select do |managed_custom_image|
        managed_custom_image[:name].start_with?(stemcell_uuid, name)
      end
      managed_custom_images.each do |managed_custom_image|
        managed_custom_image_name = managed_custom_image[:name]
        @logger.info("Delete managed custom image '#{managed_custom_image_name}'")
        @azure_client.delete_managed_custom_image(managed_custom_image_name)
      end

      # Delete all stemcells with the given stemcell name in all storage accounts
      storage_accounts = @azure_client.list_storage_accounts
      storage_accounts.each do |storage_account|
        storage_account_name = storage_account[:name]
        @logger.info("Delete stemcell '#{name}' in the storage '#{storage_account_name}'")
        @blob_manager.delete_blob(storage_account_name, STEMCELL_CONTAINER, "#{name}.vhd") if has_stemcell?(storage_account_name, name)
      end

      # Delete all records whose PartitionKey is the given stemcell name
      @meta_store.delete_stemcell_meta(name) if @meta_store.meta_enabled
    end

    def has_stemcell?(storage_account_name, name)
      @logger.info("has_stemcell?(#{storage_account_name}, #{name})")
      blob_properties = @blob_manager.get_blob_properties(storage_account_name, STEMCELL_CONTAINER, "#{name}.vhd")
      !blob_properties.nil?
    end

    def get_managed_custom_image_info(stemcell_name, storage_account_type, location)
      @logger.info("get_managed_custom_image_info(#{stemcell_name}, #{storage_account_type}, #{location})")
      managed_custom_image = _get_managed_custom_image(stemcell_name, storage_account_type, location)
      StemcellInfo.new(managed_custom_image[:id], managed_custom_image[:tags])
    end

    private

    def _get_managed_custom_image(stemcell_name, storage_account_type, location)
      @logger.info("_get_managed_custom_image(#{stemcell_name}, #{storage_account_type}, #{location})")

      # The old managed custom image name's length exceeds 80 in some location, which would cause the creation failure.
      # Old format: bosh-stemcell-<UUID>-Standard_LRS-<LOCATION>, bosh-stemcell-<UUID>-Premium_LRS-<LOCATION>
      # New format: <UUID>-S-<LOCATION>, <UUID>-P-<LOCATION>
      managed_custom_image_name_deprecated = "#{stemcell_name}-#{storage_account_type}-#{location}"
      managed_custom_image_name = managed_custom_image_name_deprecated.sub("#{STEMCELL_PREFIX}-", '')
                                                  .sub(STORAGE_ACCOUNT_TYPE_STANDARD_LRS, 'S')
                                                  .sub(STORAGE_ACCOUNT_TYPE_STANDARDSSD_LRS, 'SSSD')
                                                  .sub(STORAGE_ACCOUNT_TYPE_PREMIUM_LRS, 'P')
      managed_custom_image = @azure_client.get_managed_custom_image_by_name(managed_custom_image_name)
      return managed_custom_image unless managed_custom_image.nil?

      default_storage_account = @storage_account_manager.default_storage_account
      default_storage_account_name = default_storage_account[:name]
      cloud_error("get_managed_custom_image: Failed to get managed custom image for the stemcell '#{stemcell_name}' because the stemcell doesn't exist in the default storage account '#{default_storage_account_name}'") unless has_stemcell?(default_storage_account_name, stemcell_name)

      storage_account_name = nil
      if location == default_storage_account[:location]
        storage_account_name = default_storage_account_name
      else
        # The storage account will only be used when preparing a stemcell in the target location for managed custom image, ANY storage account type is ok.
        # To make it consistent, 'Standard_LRS' is used.
        storage_account = @storage_account_manager.get_or_create_storage_account_by_tags(STEMCELL_STORAGE_ACCOUNT_TAGS, STORAGE_ACCOUNT_TYPE_STANDARD_LRS, STORAGE_ACCOUNT_KIND_GENERAL_PURPOSE_V1, location, [STEMCELL_CONTAINER], false)
        storage_account_name = storage_account[:name]

        flock("#{CPI_LOCK_COPY_STEMCELL}-#{stemcell_name}-#{storage_account_name}", File::LOCK_EX) do
          unless has_stemcell?(storage_account_name, stemcell_name)
            @logger.info("get_managed_custom_image: Copying the stemcell from the default storage account '#{default_storage_account_name}' to the storage acccount '#{storage_account_name}'")
            stemcell_source_blob_uri = get_stemcell_uri(default_storage_account_name, stemcell_name)
            @blob_manager.copy_blob(storage_account_name, STEMCELL_CONTAINER, "#{stemcell_name}.vhd", stemcell_source_blob_uri)
          end
        end
      end

      stemcell_info = get_stemcell_info(storage_account_name, stemcell_name)
      managed_custom_image_params = {
        name: managed_custom_image_name,
        location: location,
        tags: stemcell_info.metadata,
        os_type: stemcell_info.os_type,
        source_uri: stemcell_info.uri,
        account_type: storage_account_type
      }

      flock("#{CPI_LOCK_CREATE_USER_IMAGE}-#{managed_custom_image_name}", File::LOCK_EX) do
        @azure_client.delete_managed_custom_image(managed_custom_image_name_deprecated) # CPI will cleanup the managed custom image with the old format name

        managed_custom_image = @azure_client.get_managed_custom_image_by_name(managed_custom_image_name)
        if managed_custom_image.nil?
          @azure_client.create_managed_custom_image(managed_custom_image_params)
          managed_custom_image = @azure_client.get_managed_custom_image_by_name(managed_custom_image_name)
          cloud_error("get_managed_custom_image: Can not find a managed custom image with the name '#{managed_custom_image_name}'") if managed_custom_image.nil?
        end
      end

      managed_custom_image
    end
  end
end
