module Bosh::AzureCloud
  class DiskManager2
    OS_DISK_PREFIX         = 'bosh-disk-os'
    DATA_DISK_PREFIX       = 'bosh-disk-data'
    EPHEMERAL_DISK_POSTFIX = 'ephemeral'

    include Bosh::Exec
    include Helpers

    attr_writer :resource_pool

    def initialize(azure_properties, blob_manager, azure_client2)
      @azure_properties = azure_properties
      @blob_manager = blob_manager
      @azure_client2 = azure_client2
      @logger = Bosh::Clouds::Config.logger
    end

    ##
    # Creates a disk (possibly lazily) that will be attached later to a VM.
    #
    # @param [Integer] size disk size in GiB
    # @param [string] location
    # @param [Hash] cloud_properties cloud properties to create the disk
    # @return [String] disk name
    def create_disk(size, location, cloud_properties)
      @logger.info("create_disk(#{size}, #{location}, #{cloud_properties})")
      storage_account_type = 'Standard_LRS'
      caching = 'None'
      if !cloud_properties.nil?
        if !cloud_properties['caching'].nil?
          caching = cloud_properties['caching']
          validate_disk_caching(caching)
        end
        if !cloud_properties['storage_account_type'].nil?
          storage_account_type = cloud_properties['storage_account_type']
        end
      end
      disk_name = generate_data_disk_name(caching)
      tags = {
        "user-agent" => "bosh",
        "caching" => caching
      }
      disk_params = {
        :name => disk_name,
        :location => location,
        :tags => tags,
        :disk_size => size,
        :account_type => storage_account_type
      }
      @logger.info("Start to create an empty managed disk `#{disk_name}'")
      @azure_client2.create_empty_managed_disk(disk_params)
      disk_name
    end

    def create_disk_from_blob(disk_name, blob_uri, location, storage_account_type)
      caching = get_data_disk_caching(disk_name)
      tags = {
        "user-agent" => "bosh",
        "caching" => caching,
        "original_blob" => blob_uri
      }
      disk_params = {
        :name => disk_name,
        :location => location,
        :tags => tags,
        :source_uri => blob_uri,
        :account_type => storage_account_type
      }
      @logger.info("Start to create a managed disk `#{disk_name}' from the source uri `#{blob_uri}'")
      @azure_client2.create_managed_disk_from_blob(disk_params)
      disk_name
    end

    def delete_disk(disk_name)
      @logger.info("delete_disk(#{disk_name})")
      @azure_client2.delete_managed_disk(disk_name)
    end

    def has_disk?(disk_name)
      @logger.info("has_disk?(#{disk_name})")
      disk = get_disk(disk_name)
      !disk.nil?
    end

    def get_disk(disk_name)
      @logger.info("get_disk(#{disk_name})")
      disk = @azure_client2.get_managed_disk_by_name(disk_name)
    end

    def list_disks()
      @logger.info("list_disks()")
      disks = @azure_client2.list_managed_disks()
    end

    def snapshot_disk(disk_name, metadata)
      @logger.info("snapshot_disk(#{disk_name}, #{metadata})")
      snapshot_name = generate_snapshot_name()
      snapshot_params = {
        :name => snapshot_name,
        :tags => {
          "original" => disk_name
        },
        :disk_name => disk_name
      }
      @logger.info("Start to create a snapshot `#{snapshot_name}' from a managed disk `#{disk_name}'")
      @azure_client2.create_managed_snapshot(snapshot_params)
      snapshot_name
    end

    def delete_snapshot(snapshot_id)
      @logger.info("delete_snapshot(#{snapshot_id})")
      @azure_client2.delete_managed_snapshot(snapshot_id)
    end

    # bosh-disk-os-INSTANCEID
    def generate_os_disk_name(instance_id)
      "#{OS_DISK_PREFIX}-#{instance_id}"
    end

    # bosh-disk-os-INSTANCEID-ephemeral
    def generate_ephemeral_disk_name(instance_id)
      "#{OS_DISK_PREFIX}-#{instance_id}-#{EPHEMERAL_DISK_POSTFIX}"
    end

    def os_disk(instance_id, minimum_disk_size)
      disk_size = nil
      root_disk = @resource_pool.fetch('root_disk', {})
      size = root_disk.fetch('size', nil)
      unless size.nil?
        cloud_error("root_disk.size `#{size}' is smaller than the default OS disk size `#{minimum_disk_size}' MiB") if size < minimum_disk_size
        disk_size = (size/1024.0).ceil
        validate_disk_size(disk_size*1024)
      end

      disk_caching = @resource_pool.fetch('caching', 'ReadWrite')
      validate_disk_caching(disk_caching)

      # The default OS disk size depends on the size of the VHD in the stemcell which is 3 GiB for now.
      # When using OS disk to store the ephemeral data and root_disk.size is not set, resize it to 30 GiB.
      if disk_size.nil? && ephemeral_disk(instance_id).nil?
        disk_size = 30
      end

      return {
        :disk_name    => generate_os_disk_name(instance_id),
        :disk_size    => disk_size,
        :disk_caching => disk_caching
      }
    end

    def ephemeral_disk(instance_id)
      ephemeral_disk = @resource_pool.fetch('ephemeral_disk', {})
      use_root_disk = ephemeral_disk.fetch('use_root_disk', false)
      return nil if use_root_disk

      disk_info = DiskInfo.for(@resource_pool['instance_type'])
      disk_size = disk_info.size
      size = ephemeral_disk.fetch('size', nil)
      unless size.nil?
        validate_disk_size(size)
        disk_size = size/1024
      end

      return {
        :disk_name    => generate_ephemeral_disk_name(instance_id),
        :disk_size    => disk_size,
        :disk_caching => 'ReadWrite'
      }
    end

    def get_data_disk_caching(disk_name)
      @logger.info("get_data_disk_caching(#{disk_name})")
      ret = disk_name.match("(.*)-([^-]*)$")
      caching = ret[2] unless ret.nil?
    end

    private

    # bosh-disk-data-INSTANCEID-caching
    def generate_data_disk_name(caching)
      "#{DATA_DISK_PREFIX}-#{SecureRandom.uuid}-#{caching}"
    end

    # bosh-disk-data-INSTANCEID
    def generate_snapshot_name()
      "#{DATA_DISK_PREFIX}-#{SecureRandom.uuid}"
    end
  end
end
