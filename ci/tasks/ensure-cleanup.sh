#!/usr/bin/env bash

set -e

: ${AZURE_ENVIRONMENT:?}
: ${AZURE_CLIENT_ID:?}
: ${AZURE_CLIENT_SECRET:?}
: ${AZURE_TENANT_ID:?}

: ${METADATA_FILE:=environment/metadata}

azure login --environment ${AZURE_ENVIRONMENT} --service-principal -u ${AZURE_CLIENT_ID} -p ${AZURE_CLIENT_SECRET} --tenant ${AZURE_TENANT_ID}
azure config mode arm

set +e
metadata=$(cat ${METADATA_FILE})

integration_additional_resource_group_name=$(echo ${metadata} | jq -e --raw-output ".additional_resource_group_name")
integration_default_resource_group_name=$(echo ${metadata} | jq -e --raw-output ".default_resource_group_name")
bats_resource_group_name=$(echo ${metadata} | jq -e --raw-output ".resource_group_name")
resource_group_names="${integration_additional_resource_group_name} ${integration_default_resource_group_name} ${bats_resource_group_name}"
for resource_group_name  in ${resource_group_names}
do
  azure group show --name ${resource_group_name} > /dev/null 2>&1
  if [ $? -eq 0 ]
  then
    azure group delete ${resource_group_name} --quiet
  fi
done
