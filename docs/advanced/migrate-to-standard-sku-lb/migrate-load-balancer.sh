#!/bin/bash

AZURE_SUBSCRIPTION_ID="<your-subscription-id>"
AZURE_TENANT_ID="<your-tenant-id>"
AZURE_CLIENT_ID="<your-client-id>"
AZURE_CLIENT_SECRET="<your-client-secret>"
location="<your-location>"
cf_rg_name="<your-resource-group-with-cf-deployment>"
basic_lb_name="<your-basic-lb-name>"
basic_public_ip_name="your-basic-ip-name"
standard_lb_name="<your-standard-lb-name>"
standard_public_ip_name="<your-standard-ip-name>"
migration_rg_name="<your-resource-group-for-migration>"
proxy_vm_name="proxy"

az login --service-principal --tenant ${AZURE_TENANT_ID} -u ${AZURE_CLIENT_ID} -p ${AZURE_CLIENT_SECRET}
az account set -s ${AZURE_SUBSCRIPTION_ID}

standard_sku_ip_address=$(./create-standard-lb.sh ${cf_rg_name} ${standard_lb_name} ${standard_public_ip_name})

./create-proxy.sh $location ${migration_rg_name} ${proxy_vm_name} ${standard_sku_ip_address}

# TODO: Replace with the command to deploy your cloud foundry

./change-public-ip.sh $location ${migration_rg_name} ${cf_rg_name} ${basic_lb_name} ${basic_public_ip_name} ${AZURE_SUBSCRIPTION_ID} ${proxy_vm_name}
