#!/bin/bash

rg_name=$1
standard_sku_ip_address=$(az group deployment create -g ${rg_name} --template-file load-balancer-standard-sku.json --parameters loadBalancerName=$2 loadBalancerPublicIPAddressName=$3 | jq '.properties.outputs.loadBalancerPublicIPAdress.value' -r)
echo ${standard_sku_ip_address}
