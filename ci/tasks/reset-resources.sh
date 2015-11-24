#!/usr/bin/env bash

source bosh-cpi-release/ci/tasks/utils.sh

check_param AZURE_TENANT_ID
check_param AZURE_CLIENT_ID
check_param AZURE_CLIENT_SECRET
check_param AZURE_GROUP_NAME
check_param AZURE_STORAGE_ACCOUNT_NAME

azure login --service-principal -u ${AZURE_CLIENT_ID} -p ${AZURE_CLIENT_SECRET} --tenant ${AZURE_TENANT_ID}
azure config mode arm

# check if group already exists
echo "azure group list | grep ${AZURE_GROUP_NAME}"
azure group list | grep ${AZURE_GROUP_NAME}

if [ $? -eq 0 ]
then
  vms=$(azure vm list -g ${AZURE_GROUP_NAME} --json | jq '.[].name' -r)
  for vm in $vms
  do
    echo "azure vm delete -g ${AZURE_GROUP_NAME} -n $vm"
    azure vm delete -g ${AZURE_GROUP_NAME} -n $vm --quiet
  done

  nics=$(azure network nic list -g ${AZURE_GROUP_NAME} --json | jq '.[].name' -r)
  for nic in $nics
  do
    echo "azure network nic delete -g ${AZURE_GROUP_NAME} -n $nic"
    azure network nic delete -g ${AZURE_GROUP_NAME} -n $nic --quiet
  done
  
  lbs=$(azure network lb list -g ${AZURE_GROUP_NAME} --json | jq '.[].name' -r)
  for lb in $lbs
  do
    echo "azure network lb delete -g ${AZURE_GROUP_NAME} -n $lb"
    azure network lb delete -g ${AZURE_GROUP_NAME} -n $lb --quiet
  done
  
  AZURE_ACCOUNT_KEY=$(azure storage account keys list ${AZURE_STORAGE_ACCOUNT_NAME} -g ${AZURE_GROUP_NAME} --json | jq '.storageAccountKeys.key1' -r)
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
fi
