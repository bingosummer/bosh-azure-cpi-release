#!/bin/bash

location=$1
migration_rg_name=$2
cf_rg_name=$3
basic_lb_name=$4
basic_public_ip_name=$5
subscription_id=$6
proxy_vm_name=$7

echo "Before switching: $(date)"
az network lb delete --name ${basic_lb_name} --resource-group ${cf_rg_name}
az network nic ip-config update --resource-group ${migration_rg_name} --nic-name "${proxy_vm_name}VMNic" --name "ipconfig${proxy_vm_name}" --public-ip-address /subscriptions/${subscription_id}/resourceGroups/${cf_rg_name}/providers/Microsoft.Network/publicIPAddresses/${basic_public_ip_name}
echo "After switching: $(date)"
