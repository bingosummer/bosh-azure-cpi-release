module Bosh::AzureCloud
  class DiskManager
    include Bosh::Exec
    include Helpers

    attr_writer :resource_pool

    def initialize(azure_properties, blob_manager)
      @azure_properties = azure_properties
      @blob_manager = blob_manager
      @logger = Bosh::Clouds::Config.logger
    end

    def delete_disk(storage_account_name, disk_name)
      @logger.info("delete_disk(#{storage_account_name}, #{disk_name})")
      @blob_manager.delete_blob(storage_account_name, DISK_CONTAINER, "#{disk_name}.vhd") if has_disk?(storage_account_name, disk_name)
    end

    def delete_data_disk(disk_id)
      @logger.info("delete_data_disk(#{disk_id})")
      storage_account_name = disk_id.storage_account_name()
      disk_name = disk_id.disk_name()
      delete_disk(storage_account_name, disk_name)
    end

    def delete_vm_status_files(storage_account_name, prefix)
      @logger.info("delete_vm_status_files(#{storage_account_name}, #{prefix})")
      blobs = @blob_manager.list_blobs(storage_account_name, DISK_CONTAINER, prefix).select{
        |blob| blob.name =~ /status$/
      }
      blobs.each do |blob|
        @blob_manager.delete_blob(storage_account_name, DISK_CONTAINER, blob.name)
      end
    rescue => e
      @logger.debug("delete_vm_status_files - error: #{e.inspect}\n#{e.backtrace.join("\n")}")
    end

    def snapshot_disk(storage_account_name, disk_name, metadata)
      @logger.info("snapshot_disk(#{storage_account_name}, #{disk_name}, #{metadata})")
      snapshot_time = @blob_manager.snapshot_blob(storage_account_name, DISK_CONTAINER, "#{disk_name}.vhd", metadata)

      generate_snapshot_name(disk_name, snapshot_time)
    end

    def delete_snapshot(snapshot_id)
      @logger.info("delete_snapshot(#{snapshot_id})")
      storage_account_name = snapshot_id.storage_account_name()
      snapshot_name = snapshot_id.disk_name()
      disk_name, snapshot_time = parse_snapshot_name(snapshot_name)
      @blob_manager.delete_blob_snapshot(storage_account_name, DISK_CONTAINER, "#{disk_name}.vhd", snapshot_time)
    end

    ##
    # Creates a disk (possibly lazily) that will be attached later to a VM.
    #
    # @param [String]  disk_id           - instance of DiskId
    # @param [Integer] size              - disk size in GiB
    #
    # @return [void]
    def create_disk(disk_id, size)
      @logger.info("create_disk(#{disk_id}, #{size}")
      storage_account_name = disk_id.storage_account_name()
      disk_name = disk_id.disk_name()
      @logger.info("Start to create an empty vhd blob: blob_name: #{disk_name}.vhd")
      @blob_manager.create_empty_vhd_blob(storage_account_name, DISK_CONTAINER, "#{disk_name}.vhd", size)
    end

    def has_disk?(storage_account_name, disk_name)
      @logger.info("has_disk?(#{storage_account_name}, #{disk_name})")
      blob_properties = @blob_manager.get_blob_properties(storage_account_name, DISK_CONTAINER, "#{disk_name}.vhd")
      !blob_properties.nil?
    end

    def has_data_disk?(disk_id)
      @logger.info("has_data_disk?(#{disk_id})")
      storage_account_name = disk_id.storage_account_name()
      disk_name = disk_id.disk_name()
      has_disk?(storage_account_name, disk_name)
    end

    def is_migrated?(disk_id)
      @logger.info("is_migrated?(#{disk_id})")
      storage_account_name = disk_id.storage_account_name()
      disk_name = disk_id.disk_name()
      return false unless has_disk?(storage_account_name, disk_name)
      metadata = @blob_manager.get_blob_metadata(storage_account_name, DISK_CONTAINER, "#{disk_name}.vhd")
      (METADATA_FOR_MIGRATED_BLOB_DISK.to_a - metadata.to_a).empty?
    end

    def get_disk_uri(storage_account_name, disk_name)
      @logger.info("get_disk_uri(#{storage_account_name}, #{disk_name})")
      @blob_manager.get_blob_uri(storage_account_name, DISK_CONTAINER, "#{disk_name}.vhd")
    end

    def get_data_disk_uri(disk_id)
      @logger.info("get_data_disk_uri(#{disk_id})")
      storage_account_name = disk_id.storage_account_name()
      disk_name = disk_id.disk_name()
      get_disk_uri(storage_account_name, disk_name)
    end

    def get_disk_size_in_gb(disk_id)
      @logger.info("get_disk_size_in_gb(#{disk_id})")
      storage_account_name = disk_id.storage_account_name()
      disk_name = disk_id.disk_name()
      @blob_manager.get_blob_size_in_bytes(storage_account_name, DISK_CONTAINER, "#{disk_name}.vhd") / 1024 / 1024 / 1024
    end

    # bosh-os-[VM-NAME]
    def generate_os_disk_name(vm_name)
      "#{OS_DISK_PREFIX}-#{vm_name}"
    end

    # bosh-os-[VM-NAME]-ephemeral
    def generate_ephemeral_disk_name(vm_name)
      "#{OS_DISK_PREFIX}-#{vm_name}-#{EPHEMERAL_DISK_POSTFIX}"
    end

    def os_disk(storage_account_name, vm_name, stemcell_info)
      disk_name = generate_os_disk_name(vm_name)
      disk_uri = get_disk_uri(storage_account_name, disk_name)
      disk_caching = @resource_pool.fetch('caching', 'ReadWrite')
      validate_disk_caching(disk_caching)

      disk_size = nil
      minimum_disk_size = stemcell_info.disk_size
      root_disk = @resource_pool.fetch('root_disk', {})
      size = root_disk.fetch('size', nil)
      unless size.nil?
        validate_disk_size_type(size)
        if size < minimum_disk_size
          @logger.warn("root_disk.size `#{size}' MiB is smaller than the default OS disk size `#{minimum_disk_size}' MiB. root_disk.size is ignored and use `#{minimum_disk_size}' MiB as root disk size.")
          size = minimum_disk_size
        end
        disk_size = (size/1024.0).ceil
        validate_disk_size(disk_size*1024)
      end

      # The default OS disk size depends on the size of the VHD in the stemcell.
      # When using OS disk to store the ephemeral data and root_disk.size is not set,
      # For Linux, the size of the VHD in the stemcell is 3 GiB. Need more spaces to store the ephemeral data. So,
      #   resize it to the minimum disk size if the minimum disk size is larger than 30 GiB;
      #   resize it to 30 GiB if the minimum disk size is smaller than 30 GiB.
      # For Windows, the size of the VHD in the stemcell is 128 GiB. Most of the spaces are not used. 128 GiB should be enough to store the ephemeral data. So,
      #   resize it to the minimum disk size if the minimum disk size is larger than 128 GiB;
      #   resize it to 128 GiB if the minimum disk size is smaller than 128 GiB.
      if disk_size.nil? && ephemeral_disk(storage_account_name, vm_name).nil?
        minimum_required_disk_size = stemcell_info.is_windows? ? MINIMUM_REQUIRED_OS_DISK_SIZE_IN_GB_WINDOWS : MINIMUM_REQUIRED_OS_DISK_SIZE_IN_GB_LINUX
        disk_size = (minimum_disk_size/1024.0).ceil < minimum_required_disk_size ? minimum_required_disk_size : (minimum_disk_size/1024.0).ceil
      end

      return {
        :disk_name    => disk_name,
        :disk_uri     => disk_uri,
        :disk_size    => disk_size,
        :disk_caching => disk_caching
      }
    end

    def ephemeral_disk(storage_account_name, vm_name)
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
        :disk_name    => EPHEMERAL_DISK_POSTFIX,
        :disk_uri     => get_disk_uri(storage_account_name, generate_ephemeral_disk_name(vm_name)),
        :disk_size    => disk_size,
        :disk_caching => 'ReadWrite'
      }
    end

    def list_disks(storage_account_name)
      @logger.info("list_disks(#{storage_account_name})")
      disks = []
      blobs = @blob_manager.list_blobs(storage_account_name, DISK_CONTAINER).select{
        |blob| blob.name =~ /vhd$/
      }
      blobs.each do |blob|
        disk = {
          :disk_name => blob.name[0..-5]
        }
        disks << disk
      end
      disks
    end

    private

    # bosh-data-STORAGEACCOUNTNAME-UUID-CACHING--SNAPSHOTTIME
    def generate_snapshot_name(disk_name, snapshot_time)
      "#{disk_name}--#{snapshot_time}"
    end

    def parse_snapshot_name(snapshot_name)
      ret = snapshot_name.match("^(.*)--(.*)$")
      cloud_error("Invalid snapshot id #{snapshot_name}") if ret.nil?
      return ret[1], ret[2]
    end
  end
end
