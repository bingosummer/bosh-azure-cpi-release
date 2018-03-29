#!/bin/bash

location=$1
rg_name=$2
proxy_vm_name=$3
standard_sku_ip_address=$4

az group create -n ${rg_name} -l $location

az vm create --resource-group ${rg_name} --name ${proxy_vm_name} --image UbuntuLTS --generate-ssh-keys
az vm open-port --port 80 --priority 900 --resource-group ${rg_name} --name ${proxy_vm_name}
az vm open-port --port 443 --priority 901 --resource-group ${rg_name} --name ${proxy_vm_name}
az vm open-port --port 4443 --priority 902 --resource-group ${rg_name} --name ${proxy_vm_name}
proxy_vm_ip=$(az vm list-ip-addresses --resource-group ${rg_name} --name ${proxy_vm_name} | jq '.[].virtualMachine.network.publicIpAddresses[0].ipAddress' -r)

ssh ${proxy_vm_ip} "sudo apt-get update"
ssh ${proxy_vm_ip} "sudo apt-get -y install haproxy"

cat > haproxy.cfg << EOF
listen httpserver
    bind *:80
    mode tcp
    server httpserver ${standard_sku_ip_address}:80
 
listen httpsserver
    bind *:443
    mode tcp
    server httpsserver ${standard_sku_ip_address}:443

listen logserver
    bind *:4443
    mode tcp
    server logserver ${standard_sku_ip_address}:4443
EOF

scp haproxy.cfg ${proxy_vm_ip}:~/haproxy.cfg
ssh ${proxy_vm_ip} "sudo chmod 666 /etc/haproxy/haproxy.cfg"
ssh ${proxy_vm_ip} "sudo cat ~/haproxy.cfg >> /etc/haproxy/haproxy.cfg"
ssh ${proxy_vm_ip} "sudo service haproxy restart"
