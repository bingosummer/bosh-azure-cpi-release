# frozen_string_literal: true

module Bosh::AzureCloud
  class ManagedIdentity
    attr_reader :type
    attr_reader :user_assigned_identity_name
    def initialize(managed_identity_config_hash)
      @type = managed_identity_config_hash['type']
      @user_assigned_identity_name = managed_identity_config_hash['user_assigned_identity_name']
    end
  end
end
