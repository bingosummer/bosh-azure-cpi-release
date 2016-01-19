#!/usr/bin/env bash

set -e

AZURE_TENANT_ID=`grep tenant_id ~/bosh.yml | awk '{print $2}'`
AZURE_CLIENT_ID=`grep client_id ~/bosh.yml | awk '{print $2}'`
AZURE_CLIENT_SECRET=`grep client_secret ~/bosh.yml | awk '{print $2}'`
SUBSCRIPTION_ID=`grep subscription_id ~/bosh.yml | awk '{print $2}'`
RESOURCE_GROUP_NAME=`grep resource_group_name ~/bosh.yml | awk '{print $2}'`
VIRTUAL_NETWORK_NAME=`grep virtual_network_name ~/bosh.yml | awk '{print $2}'`
SUBNET_NAME="ApplicationGateway"
SUBNET_PREFIX="10.0.1.0/24"

echo "Login Azure CLI"
azure login --service-principal -u ${AZURE_CLIENT_ID} -p ${AZURE_CLIENT_SECRET} --tenant ${AZURE_TENANT_ID}
azure config mode arm

subnet_actual=$(azure network vnet subnet show --resource-group ${RESOURCE_GROUP_NAME} --vnet-name ${VIRTUAL_NETWORK_NAME} --name ${SUBNET_NAME} --json | jq '.name' -r)
if [ "${subnet_actual}" != "${SUBNET_NAME}" ]; then
  azure network vnet subnet create --resource-group ${RESOURCE_GROUP_NAME} --vnet-name ${VIRTUAL_NETWORK_NAME} --name ${SUBNET_NAME} --address-prefix ${SUBNET_PREFIX}
fi

subnet_id=$(azure network vnet subnet show --resource-group ${RESOURCE_GROUP_NAME} --vnet-name ${VIRTUAL_NETWORK_NAME} --name ${SUBNET_NAME} --json | jq '.id' -r)

azure group deployment create --resource-group ${RESOURCE_GROUP_NAME} --name Deploy-Application-Gateway --template-file ./deploy-application-gateway.json
