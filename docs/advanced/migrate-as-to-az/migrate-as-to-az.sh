#!/bin/bash

AZURE_SUBSCRIPTION_ID=""
AZURE_TENANT_ID=""
AZURE_CLIENT_ID=""
AZURE_CLIENT_SECRET=""
location="southcentralus"
migration_rg_name="availability-set-to-availability-zone"
proxy_vm_name="proxy"
cf_rg_name="<resource-group-with-cf-deployment>"
basic_lb_name="cf-lb-basic"
basic_public_ip_name="cf-ip-basic"
standard_lb_name="cf-lb-standard"
standard_public_ip_name="cf-ip-standard"

az login --service-principal --tenant ${AZURE_TENANT_ID} -u ${AZURE_CLIENT_ID} -p ${AZURE_CLIENT_SECRET}
az account set -s ${AZURE_SUBSCRIPTION_ID}

standard_sku_ip_address=$(./create-standard-lb.sh ${cf_rg_name} ${standard_lb_name} ${standard_public_ip_name})

./create-proxy.sh $location ${migration_rg_name} ${proxy_vm_name} ${standard_sku_ip_address}

# Replace with the command to deploy cf

./change-public-ip.sh $location ${migration_rg_name} ${cf_rg_name} ${basic_lb_name} ${basic_public_ip_name} ${AZURE_SUBSCRIPTION_ID} ${proxy_vm_name}
