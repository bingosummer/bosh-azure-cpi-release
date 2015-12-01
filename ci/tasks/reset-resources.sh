#!/usr/bin/env bash

set -e

source bosh-cpi-release/ci/tasks/utils.sh

check_param AZURE_TENANT_ID
check_param AZURE_CLIENT_ID
check_param AZURE_CLIENT_SECRET
check_param AZURE_GROUP_NAME
check_param AZURE_STORAGE_ACCOUNT_NAME

azure login --service-principal -u ${AZURE_CLIENT_ID} -p ${AZURE_CLIENT_SECRET} --tenant ${AZURE_TENANT_ID}
azure config mode arm

# Exit 1 if the resource group does not exist
echo "azure group list | grep ${AZURE_GROUP_NAME}"
echo "Should run the task recreate-infrastructure-primary if the resource group does not exist!"
azure group list | grep ${AZURE_GROUP_NAME}

vms=$(azure vm list --resource-group ${AZURE_GROUP_NAME} --json | jq '.[].name' -r)
for vm in $vms
do
  echo "azure vm delete --resource-group ${AZURE_GROUP_NAME} --name $vm"
  azure vm delete --resource-group ${AZURE_GROUP_NAME} --name $vm --quiet
done

nics=$(azure network nic list --resource-group ${AZURE_GROUP_NAME} --json | jq '.[].name' -r)
for nic in $nics
do
  echo "azure network nic delete --resource-group ${AZURE_GROUP_NAME} --name $nic"
  azure network nic delete --resource-group ${AZURE_GROUP_NAME} --name $nic --quiet
done

lbs=$(azure network lb list --resource-group ${AZURE_GROUP_NAME} --json | jq '.[].name' -r)
for lb in $lbs
do
  echo "azure network lb delete --resource-group ${AZURE_GROUP_NAME} --name $lb"
  azure network lb delete --resource-group ${AZURE_GROUP_NAME} --name $lb --quiet
done

availsets=$(azure availset list --resource-group ${AZURE_GROUP_NAME} --json | jq '.[].name' -r)
for availset in $availsets
do
  echo "azure availset delete --resource-group ${AZURE_GROUP_NAME} --name $availset"
  azure availset delete --resource-group ${AZURE_GROUP_NAME} --name $availset --quiet
done

AZURE_ACCOUNT_KEY=$(azure storage account keys list ${AZURE_STORAGE_ACCOUNT_NAME} --resource-group ${AZURE_GROUP_NAME} --json | jq '.storageAccountKeys.key1' -r)
containers="bosh stemcell"
for container in $containers
do
  blobs=$(azure storage blob list --account-name ${AZURE_STORAGE_ACCOUNT_NAME} --account-key ${AZURE_ACCOUNT_KEY} --container $container --json | jq '.[].name' -r)
  for blob in $blobs
  do
    if [ $blob != "bosh-stemcell-00000000-0000-0000-0000-0AZURECPICI0.vhd" ]; then
      echo "azure storage blob delete --account-name ${AZURE_STORAGE_ACCOUNT_NAME} --account-key ${AZURE_ACCOUNT_KEY} --container $container --blob $blob"
      azure storage blob delete --account-name ${AZURE_STORAGE_ACCOUNT_NAME} --account-key ${AZURE_ACCOUNT_KEY} --container $container --blob $blob --quiet
    fi
  done
done
