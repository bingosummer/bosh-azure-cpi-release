#!/usr/bin/env bash

set -e

: ${AZURE_ENVIRONMENT:?}
: ${AZURE_TENANT_ID:?}
: ${AZURE_SUBSCRIPTION_ID:?}
: ${AZURE_CLIENT_ID:?}
: ${AZURE_CLIENT_SECRET:?}

: ${METADATA_FILE:=environment/metadata}

metadata=$(cat ${METADATA_FILE})

az cloud set --name ${AZURE_ENVIRONMENT}
az login --service-principal -u ${AZURE_CLIENT_ID} -p ${AZURE_CLIENT_SECRET} --tenant ${AZURE_TENANT_ID}
az account set -s ${AZURE_SUBSCRIPTION_ID}

DEFAULT_RESOURCE_GROUP_NAME=$(echo ${metadata} | jq -e --raw-output ".default_resource_group_name")
STORAGE_ACCOUNT_NAME=$(echo ${metadata} | jq -e --raw-output ".storage_account_name")

account_name=${STORAGE_ACCOUNT_NAME}
account_key=$(az storage account keys list --account-name ${account_name} --resource-group ${DEFAULT_RESOURCE_GROUP_NAME} | jq '.[0].value' -r)

if [ "${IS_HEAVY_STEMCELL}" == "true" ]; then
  export STEMCELL_ID="bosh-stemcell-00000000-0000-0000-0000-0AZURECPICI0"
  export STEMCELL_PATH="/tmp/image"
  # Always upload the latest stemcell for lifecycle test
  tar -xf $(realpath stemcell/*.tgz) -C /tmp/
  tar -xf ${STEMCELL_PATH} -C /tmp/
  az storage blob upload --file /tmp/root.vhd --container-name stemcell --name ${STEMCELL_ID}.vhd --type page --account-name ${account_name} --account-key ${account_key}
else
  export STEMCELL_ID="bosh-light-stemcell-00000000-0000-0000-0000-0AZURECPICI0"
  # Use the light stemcell cloud properties to generate metadata in space-separated key=value pairs
  tar -xf $(realpath stemcell/*.tgz) -C /tmp/
  stemcell_metadata=$(ruby -r yaml -r json -e '
    data = YAML::load(STDIN.read)
    stemcell_properties = data["cloud_properties"]
    stemcell_properties["hypervisor"]="hyperv"
    metadata=""
    stemcell_properties.each do |key, value|
      if key == "image"
        metadata += "#{key}=#{JSON.dump(value)} "
      else
        metadata += "#{key}=#{value} "
      end
    end
    puts metadata' < /tmp/stemcell.MF)
  dd if=/dev/zero of=/tmp/root.vhd bs=1K count=1
  az storage blob upload --file /tmp/root.vhd --container-name stemcell --name ${STEMCELL_ID}.vhd --type page --metadata ${stemcell_metadata} --account-name ${account_name} --account-key ${account_key}
  export WINDOWS_LIGHT_STEMCELL_SKU=$(ruby -r yaml -r json -e '
    data = YAML::load(STDIN.read)
    stemcell_properties = data["cloud_properties"]
    stemcell_properties.each do |key, value|
      if key == "image"
        value.each do |k, v|
          if k == "sku"
            puts v
            break
          end
        end
      end
    end' < /tmp/stemcell.MF)
  export WINDOWS_LIGHT_STEMCELL_VERSION=$(ruby -r yaml -r json -e '
    data = YAML::load(STDIN.read)
    stemcell_properties = data["cloud_properties"]
    stemcell_properties.each do |key, value|
      if key == "image"
        value.each do |k, v|
          if k == "version"
            puts v
            break
          end
        end
      end
    end' < /tmp/stemcell.MF)
fi
