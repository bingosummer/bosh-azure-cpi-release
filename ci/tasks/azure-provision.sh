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

azure login --service-principal -u ${AZURE_CLIENT_ID} -p ${AZURE_CLIENT_SECRET} --tenant ${AZURE_TENANT_ID}
azure config mode arm

set +e

# Check if the resource group already exists
echo "azure group list | grep ${AZURE_GROUP_NAME}"
azure group list | grep ${AZURE_GROUP_NAME}

if [ $? -eq 0 ]
then
  echo "azure group delete ${AZURE_GROUP_NAME}"
  azure group delete ${AZURE_GROUP_NAME} --quiet
  echo "waiting for delete operation to finish..."
  # Wait for the completion of deleting the resource group
  azure group show ${AZURE_GROUP_NAME}
  while [ $? -eq 0 ]
  do
    azure group show ${AZURE_GROUP_NAME} > /dev/null 2>&1
    echo "..."
  done
fi

set -e

echo azure group create ${AZURE_GROUP_NAME} ${AZURE_REGION_SHORT_NAME}
azure group create ${AZURE_GROUP_NAME} ${AZURE_REGION_SHORT_NAME}
cat > provision-parameters.json << EOF
{
  "newStorageAccountName": {
    "value": "${AZURE_STORAGE_ACCOUNT_NAME}"
  },
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
azure group deployment create ${AZURE_GROUP_NAME} --template-file ./bosh-cpi-release/ci/assets/azure/provision.json --parameters-file ./provision-parameters.json

# Setup the storage account
AZURE_ACCOUNT_KEY=$(azure storage account keys list ${AZURE_STORAGE_ACCOUNT_NAME} --resource-group ${AZURE_GROUP_NAME} --json | jq '.storageAccountKeys.key1' -r)
azure storage container create --account-name ${AZURE_STORAGE_ACCOUNT_NAME} --account-key ${AZURE_ACCOUNT_KEY} --container bosh
azure storage container create --account-name ${AZURE_STORAGE_ACCOUNT_NAME} --account-key ${AZURE_ACCOUNT_KEY} --permission blob --container stemcell

export BOSH_AZURE_STEMCELL_ID="bosh-stemcell-00000000-0000-0000-0000-0AZURECPICI0"
export AZURE_STORAGE_ACCOUNT=${AZURE_STORAGE_ACCOUNT_NAME}
export AZURE_STORAGE_ACCESS_KEY=${AZURE_ACCOUNT_KEY}

set +e

# Upload a stemcell for lifecycle test if it does not exist.
# Lifycycle is used to test CPI but not stemcell so you can use any valid stemcell.
azure storage blob show stemcell ${BOSH_AZURE_STEMCELL_ID}.vhd
if [ $? -eq 1 ]; then
  tar -xf ${PWD}/stemcell/*.tgz -C /mnt/
  tar -xf /mnt/image -C /mnt/
  azure storage blob upload --quiet --blobtype PAGE /mnt/root.vhd stemcell ${BOSH_AZURE_STEMCELL_ID}.vhd
fi

# Check if the resource group already exists
AZURE_GROUP_NAME_FOR_NETWORK="${AZURE_GROUP_NAME}-1"
echo "azure group list | grep ${AZURE_GROUP_NAME_FOR_NETWORK}"
azure group list | grep ${AZURE_GROUP_NAME_FOR_NETWORK}

if [ $? -eq 0 ]
then
  echo "azure group delete ${AZURE_GROUP_NAME_FOR_NETWORK}"
  azure group delete ${AZURE_GROUP_NAME_FOR_NETWORK} --quiet
  echo "waiting for delete operation to finish..."
  # Wait for the completion of deleting the resource group
  azure group show ${AZURE_GROUP_NAME_FOR_NETWORK}
  while [ $? -eq 0 ]
  do
    azure group show ${AZURE_GROUP_NAME_FOR_NETWORK} > /dev/null 2>&1
    echo "..."
  done
fi

set -e

echo azure group create ${AZURE_GROUP_NAME_FOR_NETWORK} ${AZURE_REGION_SHORT_NAME}
azure group create ${AZURE_GROUP_NAME_FOR_NETWORK} ${AZURE_REGION_SHORT_NAME}
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
azure group deployment create ${AZURE_GROUP_NAME_FOR_NETWORK} --template-file ./bosh-cpi-release/ci/assets/azure/network.json --parameters-file ./network-parameters.json
