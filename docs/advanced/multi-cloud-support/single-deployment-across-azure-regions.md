# A single deployment across two different Azure Regions

## Set up the IaaS

This guide will deploy a single deployment across `West US 2` and `East US 2`. However, if you'd like to use Azure Availability Zones, you need to select two [regions](https://docs.microsoft.com/en-us/azure/availability-zones/az-overview#regions-that-support-availability-zones) which supports Azure Availability Zones.

| AZ | Location | Resource Group |
|:----:|:--------:|:----------- |
| z1 | West US 2 | ${PRIMARY_RESOURCE_GROUP_NAME} |
| z2 | East US 2 | ${SECONDARY_RESOURCE_GROUP_NAME} |
| z3 | West US 2 | ${PRIMARY_RESOURCE_GROUP_NAME} |

Export the names of your two resource group as the environment variable `${PRIMARY_RESOURCE_GROUP_NAME}` and `${SECONDARY_RESOURCE_GROUP_NAME}`.

```
$ export PRIMARY_RESOURCE_GROUP_NAME="YOUR-PRIMARY-RESOURCE-GROUP-NAME"
$ export SECONDARY_RESOURCE_GROUP_NAME="YOUR-SECONDARY-RESOURCE-GROUP-NAME"
```

Let's start by initializing main AZ (`z1`) to `West US 2` using the [bosh-setup](https://github.com/Azure/azure-quickstart-templates/tree/master/bosh-setup) template. Please set `loadBalancerSku` to `standard`, `autoDeployBosh` to `enabled` and `autoDeployCloudFoundry` to `false`. This will give you a working BOSH Director in a single region.

To add a second AZ (`z2`) to `East US 2` you need to perform the following actions.

* Create a new resource group in `East US 2`.

  ```
  az group create --name ${SECONDARY_RESOURCE_GROUP_NAME} --location "eastus2"
  ```

* Create a Virtual Network named `boshvnet-crp` (CIDR: `10.1.0.0/16`) in the resourse group, and create a Subnet named `CloudFoundry` (CIDR: `10.1.16.0/20`) in the virtual network.

  ```
  az network vnet create --name boshvnet-crp --resource-group ${SECONDARY_RESOURCE_GROUP_NAME} --address-prefixes "10.1.0.0/16" --location "eastus2" --subnet-name CloudFoundry --subnet-prefix "10.1.16.0/20"
  ```

* Create a network security group named `nsg-cf` in the resource group, and configure it if needed.

  ```
  az network nsg create --name nsg-cf --resource-group ${SECONDARY_RESOURCE_GROUP_NAME} --location eastus2
  az network nsg rule create --name cf-https --nsg-name nsg-cf --priority 200 --resource-group ${SECONDARY_RESOURCE_GROUP_NAME} --access Allow --direction Inbound --protocol Tcp --destination-port-ranges 443
  az network nsg rule create --name cf-log --nsg-name nsg-cf --priority 201 --resource-group ${SECONDARY_RESOURCE_GROUP_NAME} --access Allow --direction Inbound --protocol Tcp --destination-port-ranges 4443
  az network nsg rule create --name cf-http --nsg-name nsg-cf --priority 202 --resource-group ${SECONDARY_RESOURCE_GROUP_NAME} --access Allow --direction Inbound --protocol Tcp --destination-port-ranges 80
  az network nsg rule create --name cf-ssh --nsg-name nsg-cf --priority 203 --resource-group ${SECONDARY_RESOURCE_GROUP_NAME} --access Allow --direction Inbound --protocol Tcp --destination-port-ranges 2222
  ```

* Create a load balancer named `cf-lb` using the [template](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/bosh-setup/nestedtemplates/load-balancer-standard.json). Please note down the public IP address of the load balancer.

  ```
  az group deployment create -g ${SECONDARY_RESOURCE_GROUP_NAME} --template-uri https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/bosh-setup/nestedtemplates/load-balancer-standard.json
  ```

>NOTE: The virtual network name, network security group name and load balancer name in `East US 2` **MUST** be same with the names in `West US 2`.

## Connecting Virtual Network

The VMs in one AZ need to be able to talk to VMs in the other AZ. You will need to connect them through a [VNet-to-VNet VPN gateway](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-vnet-vnet-resource-manager-portal).

1. [Create a gateway subnet](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-vnet-vnet-resource-manager-portal#gatewaysubnet) for the VNet in two resource groups.
1. [Create a virtual network gateway](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-vnet-vnet-resource-manager-portal#CreatVNet) in two resource groups.
1. [Configure the gateway connection](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-vnet-vnet-resource-manager-portal#TestVNet1Connection) between two gateways in previous steps. The `conntection type` should be `VNet-to-VNet`.
1. [Verify your connections](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-vnet-vnet-resource-manager-portal#VerifyConnection).

## Configure CPI and Cloud configs

Now that the IaaS is configured, update your Director's CPI config.

Create a new file `cpi.yml` with the following contents:

```yaml
cpis:
- name: azure-west-us-2
  type: azure
  properties:
    environment: AzureCloud
    subscription_id: ((subscription_id))
    tenant_id: ((tenant_id))
    client_id: ((client_id))
    client_secret: ((client_secret))
    resource_group_name: ((primary_resource_group_name))
    ssh_user: vcap
    ssh_public_key: ((ssh_public_key))
- name: azure-east-us-2
  type: azure
  properties:
    environment: AzureCloud
    subscription_id: ((subscription_id))
    tenant_id: ((tenant_id))
    client_id: ((client_id))
    client_secret: ((client_secret))
    resource_group_name: ((secondary_resource_group_name))
    ssh_user: vcap
    ssh_public_key: ((ssh_public_key))
```

You can use same or different service principals for `azure-west-us-2` and `azure-east-us-2`.

```shell
$ bosh update-cpi-config cpi.yml \
  -v subscription_id=<your-subscription-id> \
  -v tenant_id=<your-tenant-id> \
  -v client_id=<your-client-id> \
  -v client_secret=<your-client-secret> \
  -v primary_resource_group_name=${PRIMARY_RESOURCE_GROUP_NAME} \
  -v secondary_resource_group_name=${SECONDARY_RESOURCE_GROUP_NAME} \
  -v ssh_public_key="$(bosh int ~/bosh-deployment-vars.yml --path /ssh/public_key)"
```

And use following content to replace `azs` and `networks` field in your original cloud config:

>NOTE: The `azs` section of your `cloud-config` now contains the `cpi` key with available values that are defined in your `cpi-config`.

```yaml
azs:
- name: z1
  cpi: azure-west-us-2
- name: z2
  cpi: azure-east-us-2
- name: z3
  cpi: azure-west-us-2

networks:
- name: default
  type: manual
  subnets:
  - azs:
    - z1
    - z3
    cloud_properties:
      security_group: nsg-cf
      subnet_name: CloudFoundry
      virtual_network_name: boshvnet-crp
    dns:
    - 8.8.8.8
    - 168.63.129.16
    gateway: 10.0.16.1
    range: 10.0.16.0/20
    reserved:
    - 10.0.16.0
    - 10.0.16.1
    - 10.0.16.2
    - 10.0.16.3
    - 10.0.16.255
  - azs:
    - z2
    cloud_properties:
      security_group: nsg-cf
      subnet_name: CloudFoundry
      virtual_network_name: boshvnet-crp
    dns:
    - 8.8.8.8
    - 168.63.129.16
    gateway: 10.1.16.1
    range: 10.1.16.0/20
    reserved:
    - 10.1.16.0
    - 10.1.16.1
    - 10.1.16.2
    - 10.1.16.3
    - 10.1.16.255
- name: vip
  type: vip
```

If you'd like to use Azure Availability Zones, you need to configure `availability_zone`:

```yaml
azs:
- name: z1
  cpi: azure-west-europe
  cloud_properties:
    availability_zone: '1'
- name: z2
  cpi: azure-east-us-2
  cloud_properties:
    availability_zone: '1'
- name: z3
  cpi: azure-west-europe
  cloud_properties:
    availability_zone: '2'
```


Update your cloud config.

```shell
$ bosh update-cloud-config ~/example_manifests/cloud-config.yml \
  -v load_balancer_name=cf-lb
```

## Deploy Cloud Foundry

Now you can deploy Cloud Foundry across `West US 2` and `East US 2`.

1. Remove the ops file `scale-to-one-az.yml`.

1. By default, there is one instance in each az. Add instance number if needed.

1. Use a real domain as the system domain. E.g. `microsoftlovelinux.com`.

## Create a Traffic Manager Profile

1. [Specify the DNS name label](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/portal-create-fqdn) for the public IP of the Load Balancer, you can specify the DNS name label to any vaild no-empty string.

    * `cf-lb-ip.westus2.cloudapp.azure.com`

    * `cf-lb-ip.eastus2.cloudapp.azure.com`

1. Create a traffic manager profile. Select `Performance` as the traffic-routing method, `TCP` as the Monitor Protocal and `443` as the Monitor Port.

    ```
    export TRAFFIC_MANAGER_DNS_NAME="cloudfoundry"
    az network traffic-manager profile create --name CloudFoundryTrafficManagerProfile --resource-group ${PRIMARY_RESOURCE_GROUP_NAME} --routing-method Performance --unique-dns-name ${TRAFFIC_MANAGER_DNS_NAME} --monitor-protocol TCP --monitor-port 443 --monitor-path ""
    ```

    `TRAFFIC_MANAGER_DNS_NAME` is the Relative DNS name for the traffic manager profile. Resulting FQDN will be `${TRAFFIC_MANAGER_DNS_NAME}.trafficmanager.net` and must be globally unique.

1. Create endpoints for two public IPs in different regions. Select `Azure endpoints` as the endpoint type.

    ```
    az network traffic-manager endpoint create --name WestUS2Endpoint --profile-name CloudFoundryTrafficManagerProfile --resource-group ${PRIMARY_RESOURCE_GROUP_NAME} --type azureEndpoints --target-resource-id $(az network public-ip show --name <PUBLIC_IP_NAME_OF_LOAD_BALANCER> --resource-group ${PRIMARY_RESOURCE_GROUP_NAME} | jq '.id' -r)
    az network traffic-manager endpoint create --name EastUS2Endpoint --profile-name CloudFoundryTrafficManagerProfile --resource-group ${PRIMARY_RESOURCE_GROUP_NAME} --type azureEndpoints --target-resource-id $(az network public-ip show --name <PUBLIC_IP_NAME_OF_LOAD_BALANCER> --resource-group ${SECONDARY_RESOURCE_GROUP_NAME} | jq '.id' -r)
    ```

See more details in the [doc](https://docs.microsoft.com/en-us/azure/traffic-manager/traffic-manager-create-profile).

## Create an Azure DNS Zone

1. Create a DNS zone

    ```
    export ZONE_NAME="microsoftlovelinux.com"
    az network dns zone create --resource-group ${PRIMARY_RESOURCE_GROUP_NAME} --name ${ZONE_NAME}
    ```

1. Create DNS records

    1. Create a CNAME record set

        ```
        az network dns record-set cname create --resource-group ${PRIMARY_RESOURCE_GROUP_NAME} --zone-name ${ZONE_NAME} --name "*"
        ```

    1. Add a record into the resord set

        ```
        az network dns record-set cname set-record --resource-group ${PRIMARY_RESOURCE_GROUP_NAME} --zone-name ${ZONE_NAME} --record-set-name "*" --cname "${TRAFFIC_MANAGER_DNS_NAME}.trafficmanager.net"
        ```

## Confiure DNS server to Azure DNS

1. Get your Name Server Domain Name. You can get four `nsdname` from the output.

    ```
    az network dns record-set ns show --resource-group ${PRIMARY_RESOURCE_GROUP_NAME} --zone-name ${ZONE_NAME} --name "@"
    ```

1. Configure DNS server. It may differ from each provider, but the process is basically same. You can usually get the guidance in your domain-name service provider about how to configure your name server domain name.

## Login your Cloud Foundry

```
cf login -a https://api.microsoftlovelinux.com -u admin -p "$(bosh int ~/cf-deployment-vars.yml --path /cf_admin_password)" --skip-ssl-validation
```
