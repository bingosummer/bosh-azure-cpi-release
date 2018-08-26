# A single deployment across Azure and Azure Stack

## Set up the IaaS

This guide will deploy a single deployment across Azure and Azure Stack.

| AZ | Cloud | Resource Group |
|:----:|:--------:|:----------- |
| z1 | Azure | ${PRIMARY_RESOURCE_GROUP_NAME} |
| z2 | Azure Stack | ${SECONDARY_RESOURCE_GROUP_NAME} |
| z3 | Azure | ${PRIMARY_RESOURCE_GROUP_NAME} |

Export the names of your two resource group as the environment variable `${PRIMARY_RESOURCE_GROUP_NAME}` and `${SECONDARY_RESOURCE_GROUP_NAME}`.

```
$ export PRIMARY_RESOURCE_GROUP_NAME="YOUR-PRIMARY-RESOURCE-GROUP-NAME"
$ export SECONDARY_RESOURCE_GROUP_NAME="YOUR-SECONDARY-RESOURCE-GROUP-NAME"
$ export LOCATION="AZURE-STACK-LOCAION"
```

Let's start by initializing main AZ (`z1`) to Azure using the [bosh-setup](https://github.com/Azure/azure-quickstart-templates/tree/master/bosh-setup) template. Please set `loadBalancerSku` to `standard`, `autoDeployBosh` to `enabled` and `autoDeployCloudFoundry` to `false`. This will give you a working BOSH Director in a single region.

To add a second AZ (`z2`) to Azure Stack, you need to perform the following actions.

* Create a new resource group in Azure Stack.

  ```
  az group create --name ${SECONDARY_RESOURCE_GROUP_NAME} --location $LOCATION
  ```

* Create a Virtual Network named `boshvnet-crp` (CIDR: `10.1.0.0/16`) in the resourse group, and create a Subnet named `CloudFoundry` (CIDR: `10.1.16.0/20`) in the virtual network.

  ```
  az network vnet create --name boshvnet-crp --resource-group ${SECONDARY_RESOURCE_GROUP_NAME} --address-prefixes "10.1.0.0/16" --location $LOCATION --subnet-name CloudFoundry --subnet-prefix "10.1.16.0/20"
  ```

* Create a network security group named `nsg-cf` in the resource group, and configure it if needed.

  ```
  az network nsg create --name nsg-cf --resource-group ${SECONDARY_RESOURCE_GROUP_NAME} --location $LOCATION
  az network nsg rule create --name cf-https --nsg-name nsg-cf --priority 200 --resource-group ${SECONDARY_RESOURCE_GROUP_NAME} --access Allow --direction Inbound --protocol Tcp --destination-port-range 443
  az network nsg rule create --name cf-log --nsg-name nsg-cf --priority 201 --resource-group ${SECONDARY_RESOURCE_GROUP_NAME} --access Allow --direction Inbound --protocol Tcp --destination-port-range 4443
  az network nsg rule create --name cf-http --nsg-name nsg-cf --priority 202 --resource-group ${SECONDARY_RESOURCE_GROUP_NAME} --access Allow --direction Inbound --protocol Tcp --destination-port-range 80
  az network nsg rule create --name cf-ssh --nsg-name nsg-cf --priority 203 --resource-group ${SECONDARY_RESOURCE_GROUP_NAME} --access Allow --direction Inbound --protocol Tcp --destination-port-range 2222
  ```

* Create a load balancer named `cf-lb` using the [template](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/bosh-setup/nestedtemplates/load-balancer-basic.json). Please note down the public IP address of the load balancer.

  ```
  az group deployment create -g ${SECONDARY_RESOURCE_GROUP_NAME} --template-uri https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/bosh-setup/nestedtemplates/load-balancer-basic.json
  ```

>NOTE: The virtual network name, network security group name and load balancer name in Azure Stack **MUST** be same with the names in Azure.

## Connecting Virtual Network

The VMs in Azure Stack need to be able to talk to VMs in Azure. You will need to connect them through a [site-to-site VPN gateway](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-connect-vpn).

## Configure CPI and Cloud configs

Now that the IaaS is configured, update your Director's CPI config.

Create a new file `cpi.yml` with the following contents:

```yaml
cpis:
- name: azure-cloud
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
- name: azure-stack
  type: azure
  properties:
    environment: AzureStack
    subscription_id: ((subscription_id_2))
    tenant_id: ((tenant_id_2))
    client_id: ((client_id_2))
    client_secret: ((client_secret_2))
    resource_group_name: ((secondary_resource_group_name))
    ssh_user: vcap
    ssh_public_key: ((ssh_public_key))
```

You can use same or different service principals for `azure-cloud` and `azure-stack`.

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
  cpi: azure-cloud
- name: z2
  cpi: azure-stack
- name: z3
  cpi: azure-cloud

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

Update your cloud config.

```shell
$ bosh update-cloud-config ~/example_manifests/cloud-config.yml \
  -v load_balancer_name=cf-lb
```

## Deploy Cloud Foundry

Now you can deploy Cloud Foundry across Azure and Azure Stack.

1. Remove the ops file `scale-to-one-az.yml`.

1. By default, there is one instance in each az. Add instance number if needed.

1. Use a real domain as the system domain. E.g. `microsoftlovelinux.com`.

## Create a Traffic Manager Profile

1. Create a traffic manager profile. Select `Performance` as the traffic-routing method, `TCP` as the Monitor Protocal and `443` as the Monitor Port.

    ```
    export TRAFFIC_MANAGER_DNS_NAME="cloudfoundry"
    az network traffic-manager profile create --name CloudFoundryTrafficManagerProfile --resource-group ${PRIMARY_RESOURCE_GROUP_NAME} --routing-method Performance --unique-dns-name ${TRAFFIC_MANAGER_DNS_NAME} --monitor-protocol TCP --monitor-port 443 --monitor-path ""
    ```

    `TRAFFIC_MANAGER_DNS_NAME` is the Relative DNS name for the traffic manager profile. Resulting FQDN will be `${TRAFFIC_MANAGER_DNS_NAME}.trafficmanager.net` and must be globally unique.

1. Create endpoints for two public IPs in Azure and Azure Stack. Select `External endpoints` as the endpoint type. For the location of Azure Stack endpoint, select the nearest location.

    ```
    az network traffic-manager endpoint create --name AzureEndpoint --profile-name CloudFoundryTrafficManagerProfile --resource-group ${PRIMARY_RESOURCE_GROUP_NAME} --type externalEndpoints --endpoint-location WestUS2 --target <PUBLIC_IP_ADDRESS_OF_LOAD_BALANCER_IN_AZURE>
    az network traffic-manager endpoint create --name AzureStackEndpoint --profile-name CloudFoundryTrafficManagerProfile --resource-group ${PRIMARY_RESOURCE_GROUP_NAME} --type externalEndpoints --endpoint-location WestUS --target <PUBLIC_IP_ADDRESS_OF_LOAD_BALANCER_IN_AZURE_STACK>
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
