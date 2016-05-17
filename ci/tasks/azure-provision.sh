#!/usr/bin/env bash

set -e

source bosh-cpi-release/ci/tasks/utils.sh

check_param AZURE_CLIENT_ID
check_param AZURE_CLIENT_SECRET
check_param AZURE_TENANT_ID
check_param AZURE_GROUP_NAME
check_param AZURE_REGION_NAME
check_param AZURE_REGION_SHORT_NAME
check_param AZURE_STORAGE_ACCOUNT_NAME
check_param AZURE_VNET_NAME_FOR_BATS
check_param AZURE_VNET_NAME_FOR_LIFECYCLE
check_param AZURE_BOSH_SUBNET_NAME
check_param AZURE_CF_SUBNET_NAME

AZURE_GROUP_NAME_FOR_NETWORK="${AZURE_GROUP_NAME}-network"
AZURE_GROUP_NAME_FOR_OTHERS="${AZURE_GROUP_NAME}-others"

azure login --service-principal -u ${AZURE_CLIENT_ID} -p ${AZURE_CLIENT_SECRET} --tenant ${AZURE_TENANT_ID}
azure config mode arm

set +e

resource_group_names="${AZURE_GROUP_NAME} ${AZURE_GROUP_NAME_FOR_NETWORK} ${AZURE_GROUP_NAME_FOR_OTHERS}"
for resource_group_name in $resource_group_names
do
  # Check if the resource group already exists
  echo "azure group list | grep ${resource_group_name}"
  azure group list | grep ${resource_group_name}
  
  if [ $? -eq 0 ]
  then
    echo "azure group delete ${resource_group_name}"
    azure group delete ${resource_group_name} --quiet
    echo "waiting for delete operation to finish..."
    # Wait for the completion of deleting the resource group
    azure group show ${resource_group_name}
    while [ $? -eq 0 ]
    do
      azure group show ${resource_group_name} > /dev/null 2>&1
      echo "..."
    done
  fi
done

set -e

resource_group_names="${AZURE_GROUP_NAME} ${AZURE_GROUP_NAME_FOR_NETWORK}"
for resource_group_name in $resource_group_names
do
  echo azure group create ${resource_group_name} ${AZURE_REGION_SHORT_NAME}
  azure group create ${resource_group_name} ${AZURE_REGION_SHORT_NAME}
  cat > network-parameters.json << EOF
  {
    "virtualNetworkNameForBats": {
      "value": "${AZURE_VNET_NAME_FOR_BATS}"
    },
    "virtualNetworkNameForLifecycle": {
      "value": "${AZURE_VNET_NAME_FOR_LIFECYCLE}"
    },
    "subnetNameForBosh": {
      "value": "${AZURE_BOSH_SUBNET_NAME}"
    },
    "subnetNameForCloudFoundry": {
      "value": "${AZURE_CF_SUBNET_NAME}"
    }
  }
EOF
  azure group deployment create ${resource_group_name} --template-file ./bosh-cpi-release/ci/assets/azure/network.json --parameters-file ./network-parameters.json
done

resource_group_names="${AZURE_GROUP_NAME} ${AZURE_GROUP_NAME_FOR_OTHERS}"
for resource_group_name in $resource_group_names
do
  if [ "${resource_group_name}" = "${AZURE_GROUP_NAME_FOR_OTHERS}" ]; then
    storage_account_name="${AZURE_STORAGE_ACCOUNT_NAME}"
  else
    storage_account_name="${AZURE_STORAGE_ACCOUNT_NAME}others"
  fi
  echo azure group create ${resource_group_name} ${AZURE_REGION_SHORT_NAME}
  azure group create ${resource_group_name} ${AZURE_REGION_SHORT_NAME}
  cat > others-parameters.json << EOF
  {
    "newStorageAccountName": {
      "value": "${storage_account_name}"
    }
  }
EOF
  azure group deployment create ${resource_group_name} --template-file ./bosh-cpi-release/ci/assets/azure/others.json --parameters-file ./others-parameters.json

  # Setup the storage account
  storage_account_key=$(azure storage account keys list ${storage_account_name} --resource-group ${resource_group_name} --json | jq '.storageAccountKeys.key1' -r)
  azure storage container create --account-name ${storage_account_name} --account-key ${storage_account_key} --container bosh
  azure storage container create --account-name ${storage_account_name} --account-key ${storage_account_key} --permission blob --container stemcell

  export AZURE_STORAGE_ACCOUNT=${storage_account_name}
  export AZURE_STORAGE_ACCESS_KEY=${storage_account_key}

  # Upload a stemcell for lifecycle test if it does not exist.
  # Lifycycle is used to test CPI but not stemcell so you can use any valid stemcell.
  stemcell_id="bosh-stemcell-00000000-0000-0000-0000-0AZURECPICI0"
  tar -xf ${PWD}/stemcell/*.tgz -C /mnt/
  tar -xf /mnt/image -C /mnt/
  azure storage blob upload --quiet --blobtype PAGE /mnt/root.vhd stemcell ${stemcell_id}.vhd
done
