# frozen_string_literal: true

module Bosh::AzureCloud
  class VMManager
    private

    def _get_availability_set_name(vm_props, env)
      vm_props.availability_set.nil? ? _get_bosh_group_name(env) : vm_props.availability_set
    end

    def _get_or_create_availability_set(resource_group_name, availability_set_name, vm_props, location)
      return nil if availability_set_name.nil?

      availability_set_params = {
        name: availability_set_name,
        location: location,
        tags: AZURE_TAGS,
        platform_update_domain_count: vm_props.platform_update_domain_count || default_update_domain_count,
        platform_fault_domain_count: vm_props.platform_fault_domain_count || default_fault_domain_count,
        managed: @use_managed_disks
      }
      availability_set = nil
      flock("#{CPI_LOCK_PREFIX_AVAILABILITY_SET}-#{availability_set_name}", File::LOCK_EX) do
        availability_set = @azure_client.get_availability_set_by_name(resource_group_name, availability_set_name)
        if availability_set.nil?
          @logger.info("create_availability_set - the availability set '#{availability_set_name}' doesn't exist. Will create a new one.")
          @azure_client.create_availability_set(resource_group_name, availability_set_params)
          availability_set = @azure_client.get_availability_set_by_name(resource_group_name, availability_set_name)
        # In some regions, the location of availability set is case-sensitive, e.g. CanadaCentral instead of canadacentral.
        elsif !availability_set[:location].casecmp(availability_set_params[:location]).zero?
          cloud_error("create_availability_set - the availability set '#{availability_set_name}' already exists, but in a different location '#{availability_set[:location].downcase}' instead of '#{availability_set_params[:location].downcase}'. Please delete the availability set or choose another location.")
        elsif !@use_managed_disks && availability_set[:managed]
          cloud_error("create_availability_set - the availability set '#{availability_set_name}' already exists. It's not allowed to update it from managed to unmanaged.")
        elsif @use_managed_disks && !availability_set[:managed]
          @logger.info("create_availability_set - the availability set '#{availability_set_name}' exists, but it needs to be updated from unmanaged to managed.")
          availability_set_params.merge!(
            platform_update_domain_count: availability_set[:platform_update_domain_count],
            platform_fault_domain_count: availability_set[:platform_fault_domain_count],
            managed: true
          )
          @azure_client.create_availability_set(resource_group_name, availability_set_params)
          availability_set = @azure_client.get_availability_set_by_name(resource_group_name, availability_set_name)
        else
          @logger.info("create_availability_set - the availability set '#{availability_set_name}' exists. No need to update.")
        end
      end
      cloud_error("get_or_create_availability_set - availability set '#{availability_set_name}' is not created.") if availability_set.nil?
      availability_set
    end

    def _delete_empty_availability_set(resource_group_name, availability_set_name)
      flock("#{CPI_LOCK_PREFIX_AVAILABILITY_SET}-#{availability_set_name}", File::LOCK_EX | File::LOCK_NB) do
        availability_set = @azure_client.get_availability_set_by_name(resource_group_name, availability_set_name)
        @azure_client.delete_availability_set(resource_group_name, availability_set_name) if availability_set && availability_set[:virtual_machines].empty?
      end
    end
  end
end
