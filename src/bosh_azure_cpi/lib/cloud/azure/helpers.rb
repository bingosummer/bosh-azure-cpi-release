module Bosh::AzureCloud
  module Helpers

    AZURE_RESOURCE_PROVIDER_COMPUTE          = 'crp'
    AZURE_RESOURCE_PROVIDER_NETWORK          = 'nrp'
    AZURE_RESOURCE_PROVIDER_STORAGE          = 'srp'
    AZURE_RESOURCE_PROVIDER_GROUP            = 'rp'
    AZURE_RESOURCE_PROVIDER_ACTIVEDIRECTORY  = 'ad'

    AZURE_ENVIRONMENTS = {
      'AzureCloud' => {
        'resourceManagerEndpointUrl' => 'https://management.azure.com/',
        'activeDirectoryEndpointUrl' => 'https://login.microsoftonline.com',
        'apiVersion' => {
          AZURE_RESOURCE_PROVIDER_COMPUTE          => '2016-04-30-preview',
          AZURE_RESOURCE_PROVIDER_NETWORK          => '2015-06-15',
          AZURE_RESOURCE_PROVIDER_STORAGE          => '2015-06-15',
          AZURE_RESOURCE_PROVIDER_GROUP            => '2016-06-01',
          AZURE_RESOURCE_PROVIDER_ACTIVEDIRECTORY  => '2015-06-15'
        }
      },
      'AzureChinaCloud' => {
        'resourceManagerEndpointUrl' => 'https://management.chinacloudapi.cn/',
        'activeDirectoryEndpointUrl' => 'https://login.chinacloudapi.cn',
        'apiVersion' => {
          AZURE_RESOURCE_PROVIDER_COMPUTE          => '2015-06-15',
          AZURE_RESOURCE_PROVIDER_NETWORK          => '2015-06-15',
          AZURE_RESOURCE_PROVIDER_STORAGE          => '2015-06-15',
          AZURE_RESOURCE_PROVIDER_GROUP            => '2016-06-01',
          AZURE_RESOURCE_PROVIDER_ACTIVEDIRECTORY  => '2015-06-15'
        }
      },
      'AzureUSGovernment' => {
        'resourceManagerEndpointUrl' => 'https://management.usgovcloudapi.net/',
        'activeDirectoryEndpointUrl' => 'https://login.microsoftonline.com',
        'apiVersion' => {
          AZURE_RESOURCE_PROVIDER_COMPUTE          => '2015-06-15',
          AZURE_RESOURCE_PROVIDER_NETWORK          => '2015-06-15',
          AZURE_RESOURCE_PROVIDER_STORAGE          => '2015-06-15',
          AZURE_RESOURCE_PROVIDER_GROUP            => '2016-06-01',
          AZURE_RESOURCE_PROVIDER_ACTIVEDIRECTORY  => '2015-06-15'
        }
      },
      'AzureStack' => {
        'resourceManagerEndpointUrl' => 'https://azurestack.local-api/',
        'apiVersion' => {
          AZURE_RESOURCE_PROVIDER_COMPUTE          => '2015-06-15',
          AZURE_RESOURCE_PROVIDER_NETWORK          => '2015-05-01-preview',
          AZURE_RESOURCE_PROVIDER_STORAGE          => '2015-05-01-preview',
          AZURE_RESOURCE_PROVIDER_GROUP            => '2015-05-01-preview',
          AZURE_RESOURCE_PROVIDER_ACTIVEDIRECTORY  => '2015-05-01-preview'
        }
      }
    }

    PROVISIONING_STATE_SUCCEEDED  = 'Succeeded'
    PROVISIONING_STATE_FAILED     = 'Failed'
    PROVISIONING_STATE_INPROGRESS = 'InProgress'

    # About user-agent:
    # For REST APIs, the value is "BOSH-AZURE-CPI".
    # For Azure resource tags, the value is "bosh".
    USER_AGENT_FOR_REST           = 'BOSH-AZURE-CPI'
    USER_AGENT_FOR_AZURE_RESOURCE = 'bosh'
    AZURE_TAGS                    = {
      'user-agent' => USER_AGENT_FOR_AZURE_RESOURCE
    }

    AZURE_MAX_RETRY_COUNT         = 10

    # Storage Account
    ACCOUNT_TYPE_STANDARD_LRS     = 'Standard_LRS'
    ACCOUNT_TYPE_PREMIUM_LRS      = 'Premium_LRS'
    DISK_CONTAINER                = 'bosh'
    STEMCELL_CONTAINER            = 'stemcell'
    STEMCELL_TABLE                = 'stemcells'
    PUBLIC_ACCESS_LEVEL_BLOB      = "blob"
    STEMCELL_STORAGE_ACCOUNT_TAGS = AZURE_TAGS.merge({
      'type' => 'stemcell'
    })

    # Disk
    OS_DISK_PREFIX                = 'bosh-os'
    DATA_DISK_PREFIX              = 'bosh-data'
    MANAGED_OS_DISK_PREFIX        = 'bosh-disk-os'
    MANAGED_DATA_DISK_PREFIX      = 'bosh-disk-data'
    EPHEMERAL_DISK_POSTFIX        = 'ephemeral'
    STEMCELL_PREFIX               = 'bosh-stemcell'

    EPHEMERAL_DISK_NAME           = 'ephemeral-disk'
    AZURE_SCSI_HOST_DEVICE_ID     = '{f8b3781b-1e82-4818-a1c3-63d806ec15bb}'

    # Lock
    BOSH_LOCK_TIMEOUT_EXCEPTION_MESSAGE = 'timeout'

    ##
    # Raises CloudError exception
    #
    # @param [String] message Message about what went wrong
    # @param [Exception] exception Exception to be logged (optional)
    def cloud_error(message, exception = nil)
      @logger.error(message) if @logger
      @logger.error(exception) if @logger && exception
      raise Bosh::Clouds::CloudError, message
    end

    ## Encode all values in metadata to string.
    # @param [Hash] metadata
    # @return [Hash]
    def encode_metadata(metadata)
      ret = {}
      metadata.each do |key, value|
        ret[key] = value.to_s
      end
      ret
    end

    def get_storage_account_name_from_instance_id(instance_id)
      ret = instance_id.match('^([^-]*)-(.*)$')
      cloud_error("Invalid instance id #{instance_id}") if ret.nil?
      return ret[1]
    end

    def get_storage_account_name_from_disk_id(disk_id)
      ret = disk_id.match('^bosh-data-([^-]*)-(.*)$')
      cloud_error("Invalid disk id #{disk_id}") if ret.nil?
      return ret[1]
    end

    def validate_disk_caching(caching)
      valid_caching = ['None', 'ReadOnly', 'ReadWrite']
      unless valid_caching.include?(caching)
        cloud_error("Unknown disk caching #{caching}")
      end
    end

    def ignore_exception
      begin
        yield
      rescue
      end
    end

    def get_arm_endpoint(azure_properties)
      if azure_properties['environment'] == 'AzureStack'
        validate_azure_stack_options(azure_properties)
        domain = azure_properties['azure_stack_domain']
        "https://api.#{domain}"
      else
        AZURE_ENVIRONMENTS[azure_properties['environment']]['resourceManagerEndpointUrl']
      end
    end

    def get_token_resource(azure_properties)
      AZURE_ENVIRONMENTS[azure_properties['environment']]['resourceManagerEndpointUrl']
    end

    def get_azure_authentication_endpoint_and_api_version(azure_properties)
      url = nil
      api_version = get_api_version(azure_properties, AZURE_RESOURCE_PROVIDER_ACTIVEDIRECTORY)
      if azure_properties['environment'] == 'AzureStack'
        validate_azure_stack_options(azure_properties)
        domain = azure_properties['azure_stack_domain']

        if azure_properties['azure_stack_authentication']  == 'AzureStack'
          url = "https://#{domain}/oauth2/token"
        elsif azure_properties['azure_stack_authentication']  == 'AzureStackAD'
          url = "https://#{domain}/#{azure_properties['tenant_id']}/oauth2/token"
        else
          url = "#{AZURE_ENVIRONMENTS['AzureCloud']['activeDirectoryEndpointUrl']}/#{azure_properties['tenant_id']}/oauth2/token"
          api_version = AZURE_ENVIRONMENTS['AzureCloud']['apiVersion'][AZURE_RESOURCE_PROVIDER_ACTIVEDIRECTORY]
        end
      else
        url = "#{AZURE_ENVIRONMENTS[azure_properties['environment']]['activeDirectoryEndpointUrl']}/#{azure_properties['tenant_id']}/oauth2/token"
      end

      return url, api_version
    end

    def initialize_azure_storage_client(storage_account, service = 'blob')
      azure_client = Azure::Storage::Client.create(storage_account_name: storage_account[:name], storage_access_key: storage_account[:key], user_agent_prefix: USER_AGENT_FOR_REST)

      case service
        when 'blob'
          if storage_account[:storage_blob_host].end_with?('/')
            azure_client.storage_blob_host  = storage_account[:storage_blob_host].chop
          else
            azure_client.storage_blob_host  = storage_account[:storage_blob_host]
          end
        when 'table'
          if storage_account[:storage_table_host].nil?
            cloud_error("The storage account `#{storage_account[:name]}' does not support table")
          end

          if storage_account[:storage_table_host].end_with?('/')
            azure_client.storage_table_host = storage_account[:storage_table_host].chop
          else
            azure_client.storage_table_host = storage_account[:storage_table_host]
          end
        else
          cloud_error("No support for the storage service: `#{service}'")
      end

      azure_client
    end

    def get_api_version(azure_properties, resource_provider)
      AZURE_ENVIRONMENTS[azure_properties['environment']]['apiVersion'][resource_provider]
    end

    def validate_disk_size(size)
      raise ArgumentError, 'disk size needs to be an integer' unless size.kind_of?(Integer)

      cloud_error('Azure CPI minimum disk size is 1 GiB') if size < 1024
      cloud_error('Azure CPI maximum disk size is 1023 GiB') if size > 1023 * 1024
    end

    def is_debug_mode(azure_properties)
      debug_mode = false
      debug_mode = azure_properties['debug_mode'] unless azure_properties['debug_mode'].nil?
      debug_mode
    end

    def merge_storage_common_options(options = {})
      options.merge!({ :request_id => SecureRandom.uuid })
      options
    end

    # https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-linux-sizes/
    # size: The default ephemeral disk size for the instance type
    #   Reference Azure temporary disk size as the ephemeral disk size
    #   If the size is less than 30 GiB, CPI uses 30 GiB because the space may not be enough. You can find the temporary disk size in the comment if it is less than 30 GiB
    #   If the size is larger than 1,023 GiB, CPI uses 1,023 GiB because max data disk size is 1,023 GiB on Azure. You can find the temporary disk size in the comment if it is larger than 1,023 GiB
    # count: The maximum number of data disks for the instance type
    #   The maximum number of data disks on Azure for now is 64. Set it to 64 if instance_type cannot be found in case a new instance type is supported in future
    class DiskInfo
      INSTANCE_TYPE_DISK_MAPPING = {
        # A-series
        'STANDARD_A0'  => [30, 1], # 20 GiB
        'STANDARD_A1'  => [70, 2],
        'STANDARD_A2'  => [135, 4],
        'STANDARD_A3'  => [285, 8],
        'STANDARD_A4'  => [605, 16],
        'STANDARD_A5'  => [135, 4],
        'STANDARD_A6'  => [285, 8],
        'STANDARD_A7'  => [605, 16],
        'STANDARD_A8'  => [382, 16],
        'STANDARD_A9'  => [382, 16],
        'STANDARD_A10' => [382, 16],
        'STANDARD_A11' => [382, 16],

        # D-series
        'STANDARD_D1'  => [50, 2],
        'STANDARD_D2'  => [100, 4],
        'STANDARD_D3'  => [200, 8],
        'STANDARD_D4'  => [400, 16],
        'STANDARD_D11' => [100, 4],
        'STANDARD_D12' => [200, 8],
        'STANDARD_D13' => [400, 16],
        'STANDARD_D14' => [800, 32],

        # Dv2-series
        'STANDARD_D1_V2'  => [50, 2],
        'STANDARD_D2_V2'  => [100, 4],
        'STANDARD_D3_V2'  => [200, 8],
        'STANDARD_D4_V2'  => [400, 16],
        'STANDARD_D5_V2'  => [800, 32],
        'STANDARD_D11_V2' => [100, 4],
        'STANDARD_D12_V2' => [200, 8],
        'STANDARD_D13_V2' => [400, 16],
        'STANDARD_D14_V2' => [800, 32],
        'STANDARD_D15_V2' => [1023, 40], # 1024 GiB

        # DS-series
        'STANDARD_DS1'  => [30, 2], # 7 GiB
        'STANDARD_DS2'  => [30, 4], # 14 GiB
        'STANDARD_DS3'  => [30, 8], # 28 GiB
        'STANDARD_DS4'  => [56, 16],
        'STANDARD_DS11' => [28, 4],
        'STANDARD_DS12' => [56, 8],
        'STANDARD_DS13' => [112, 16],
        'STANDARD_DS14' => [224, 32],

        # DSv2-series
        'STANDARD_DS1_V2'  => [30, 2], # 7 GiB
        'STANDARD_DS2_V2'  => [30, 4], # 14 GiB
        'STANDARD_DS3_V2'  => [30, 8], # 28 GiB
        'STANDARD_DS4_V2'  => [56, 16],
        'STANDARD_DS5_V2'  => [112, 32],
        'STANDARD_DS11_V2' => [28, 4],
        'STANDARD_DS12_V2' => [56, 8],
        'STANDARD_DS13_V2' => [112, 16],
        'STANDARD_DS14_V2' => [224, 32],
        'STANDARD_DS15_V2' => [280, 40],

        # F-series
        'STANDARD_F1'  => [30, 2], # 16 GiB
        'STANDARD_F2'  => [32, 4],
        'STANDARD_F4'  => [64, 8],
        'STANDARD_F8'  => [128, 16],
        'STANDARD_F16' => [256, 32],

        # Fs-series
        'STANDARD_F1S'  => [30, 2], # 4 GiB
        'STANDARD_F2S'  => [30, 4], # 8 GiB
        'STANDARD_F4S'  => [30, 8], # 16 GiB
        'STANDARD_F8S'  => [32, 16],
        'STANDARD_F16S' => [64, 32],

        # G-series
        'STANDARD_G1'  => [384, 4],
        'STANDARD_G2'  => [768, 8],
        'STANDARD_G3'  => [1023, 16], # 1,536 GiB
        'STANDARD_G4'  => [1023, 32], # 3,072 GiB
        'STANDARD_G5'  => [1023, 64], # 6,144 GiB

        # Gs-series
        'STANDARD_GS1'  => [56, 4],
        'STANDARD_GS2'  => [112, 8],
        'STANDARD_GS3'  => [224, 16],
        'STANDARD_GS4'  => [448, 32],
        'STANDARD_GS5'  => [896, 64]
      }

      attr_reader :size, :count

      def self.for(instance_type)
        values = INSTANCE_TYPE_DISK_MAPPING[instance_type.upcase]
        if values
          DiskInfo.new(*values)
        else
          DiskInfo.new(30, 64)
        end
      end

      def initialize(size, count)
        @size = size
        @count = count
      end
    end

    # Stemcell information
    # * +:uri+      - String. uri of the blob stemcell, e.g. "https://<storage-account-name>.blob.core.windows.net/stemcell/bosh-stemcell-82817f34-ae10-4cfe-8ca8-b18d18ee5cdd.vhd"
    #                         id of the image stemcell, e.g. "/subscriptions/<subscription-id>/resourceGroups/<resource-group-name>/providers/Microsoft.Compute/images/bosh-stemcell-d42a792c-db7a-45a6-8132-e03c863c9f01-Standard_LRS-southeastasia"
    # * +:os_type+  - String. os type of the stemcell, e.g. "linux"
    # * +:name+     - String. name of the stemcell, e.g. "bosh-azure-hyperv-ubuntu-trusty-go_agent"
    # * +:version   - String. version of the stemcell, e.g. "2972"
    # * +:disk_size - Integer. disk size in MiB, e.g. 3072
    class StemcellInfo
      attr_reader :uri, :metadata, :os_type, :name, :version, :disk_size

      def initialize(uri, metadata)
        @uri = uri
        @metadata = metadata
        @os_type = @metadata['os_type'].nil? ? 'linux': @metadata['os_type'].downcase
        @name = @metadata['name']
        @version = @metadata['version']
        @disk_size = @metadata['disk'].nil? ? 3072 : @metadata['disk'].to_i
      end
    end

    # The file mutex
    # Example codes:
    # mutex = FileMutex('/tmp/bosh-lock-example', logger, 120)
    # begin
    #   mutex.synchronize do
    #     # If your work is a long-running task, you need to update the lock. If it's not, you can just do_your_work_here.
    #     do_your_work_here do
    #       mutex.update()
    #     end
    #   end
    # rescue => e
    #   raise 'what action fails because of timeout' if e.message == BOSH_LOCK_TIMEOUT_EXCEPTION_MESSAGE
    #   raise e.inspect
    # end 
    class FileMutex
      def initialize(file_path, logger, expired = 60)
        @file_path = file_path
        @logger = logger
        @expired = expired
      end

      def synchronize
        if lock
          begin
            yield
          ensure
            unlock
          end
        else
          raise BOSH_LOCK_TIMEOUT_EXCEPTION_MESSAGE unless wait
        end
      end

      def update()
        raise "The lock doesn't exist" unless File.exists?(@file_path)
        File.open(@file_path, 'wb') { |f|
          f.write("InProgress")
        }
      end

      private

      def lock()
        if File.exists?(@file_path)
          if Time.new() - File.mtime(@file_path) > @expired
            File.delete(@file_path)
            raise BOSH_LOCK_TIMEOUT_EXCEPTION_MESSAGE
          else
            return false
          end
        else
          begin
            fd = IO::sysopen(@file_path, Fcntl::O_WRONLY | Fcntl::O_EXCL | Fcntl::O_CREAT) # Using O_EXCL, creation fails if the file exists
            f = IO.open(fd)
            f.syswrite("InProgress")
          rescue => e
            @logger.debug("Failed to create the lock file `#{@file_path}'. Error: #{e.inspect}\n#{e.backtrace.join("\n")}")
            return false
          ensure
            f.close
          end
          return true
        end
      end

      def wait()
        loop do
          return true unless File.exists?(@file_path)
          break if Time.new() - File.mtime(@file_path) > @expired
          sleep(1)
        end
        return false
      end

      def unlock()
        File.delete(@file_path) if File.exists?(@file_path)
      end
    end

    def get_storage_account_type_by_instance_type(instance_type)
      storage_account_type = ACCOUNT_TYPE_STANDARD_LRS
      instance_type = instance_type.downcase
      if instance_type.start_with?("standard_ds") || instance_type.start_with?("standard_gs") || ((instance_type =~ /^standard_f(\d)+s/) == 0)
        storage_account_type = 'Premium_LRS'
      end
      storage_account_type
    end

    def is_managed_vm?(instance_id)
      # The instance id of a Managed VM is GUID whose length is 36
      instance_id.length == 36
    end

    def is_stemcell_storage_account?(tags)
      (STEMCELL_STORAGE_ACCOUNT_TAGS.to_a - tags.to_a).empty?
    end

    private

    def validate_azure_stack_options(azure_properties)
      missing_keys = []
      missing_keys << "azure_stack_domain" if azure_properties['azure_stack_domain'].nil?
      missing_keys << "azure_stack_authentication" if azure_properties['azure_stack_authentication'].nil?
      raise ArgumentError, "missing configuration parameters for AzureStack > #{missing_keys.join(', ')}" unless missing_keys.empty?
    end
  end
end
