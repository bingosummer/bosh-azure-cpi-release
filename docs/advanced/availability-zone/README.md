# Integrating Availability Zones with Cloud Foundry on Azure

An Azure [Availability Zone](https://docs.microsoft.com/en-us/azure/availability-zones/az-overview) (AZ) is a physically separate zone within an Azure region. Within this document you will see how to integrate AZs with Cloud Foundry (CF) to implement high availability.

## Pre-requisites

* Before AZ General Availability (GA), you need to [sign up for the Availability Zones preview](http://aka.ms/azenroll) for your subscription. Please note that **NOT** all regions and VM sizes are supported. Read this [document](https://docs.microsoft.com/en-us/azure/availability-zones/az-overview) to get regions and VM sizes that support AZs.

* A BOSH director with managed disks enabled

    To setup a BOSH director on Azure, please either refer to this [document](../../get-started/via-arm-templates/deploy-bosh-via-arm-templates.md) to prepare a CF environment via Azure ARM template, or refer to this [document](https://bosh.io/docs/init-azure.html) to prepare a BOSH director using bosh CLI v2 manually.

    You need to enable managed disks in your BOSH director by setting `use_managed_disks` to `true`. Please note the VMs with unmanaged disks do **NOT** support AZ. To enable managed disks, please refer to this [link](../managed-disks/README.md).

* You need a valid deployment manifest.

    - You can either refer to this [ARM template](../../get-started/via-arm-templates/deploy-bosh-via-arm-templates.md) or [cf-deployment](https://github.com/cloudfoundry/cf-deployment) to get a CF deployment manifest.

* Prepare a [Standard SKU public IP address](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-public-ip-address) and a [Standard SKU load balancer](https://docs.microsoft.com/en-us/azure/load-balancer/load-balancer-standard-overview) (LB). Basic SKU public IP or LB does **NOT** work with AZs.

    <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fcloudfoundry-incubator%2Fbosh-azure-cpi-release%2Fmaster%2Fdocs%2Fadvanced%2Fmigrate-to-standard-sku-lb%2Fload-balancer-standard-sku.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
    </a>

## Fresh Deployment

1. Configure AZs

    - Add the cloud property `availability_zone` for `azs` in your [cloud config](https://bosh.io/docs/azure-cpi.html#azs). For examples:

        ```yaml
        azs:
        - name: z1
          cloud_properties:
            availability_zone: "1"
        - name: z2
          cloud_properties:
            availability_zone: "2"
        - name: z3
          cloud_properties:
            availability_zone: "3"

        networks:
        - name: default
          type: manual
          subnets:
          - range: ((internal_cidr))
            gateway: ((internal_gw))
            azs: [z1, z2, z3]
            dns: [168.63.129.16]
            reserved: [((internal_gw))/30]
        cloud_properties:
          …
        ```

1. Configure Load Balancer

    - If you use Azure load balancer

        Configure the cloud property `load_balancer` in your [`vm_extensions`](https://bosh.io/docs/azure-cpi.html#resource-pools) to use the Standard SKU LB.

    - If you use an Azure application gateway, no change is needed.


1. Deploy your cloud foundry.

## Migration from Existing Deployment

Say you have an existing CF deployment which is deployed with availability sets and Basic SKU LB, now you need to do the following migrations.

### Step 1: Migrate Load Balancer from Baisc SKU to Standard SKU

You can simply configure the cloud property `load_balancer` in your [`vm_extensions`](https://bosh.io/docs/azure-cpi.html#resource-pools) to use the Standard SKU LB. There are downtime during this step because the public IP address is changed when migrating SKUs. You can check this [doc](../migrate-to-standard-sku-lb/) to decrease the downtime.

### Step 2: Migrate from Availability Set to Availability Zone

Azure CPI supports migration from regional deployment to zonal deployment. There are no downtime during this step.

1. Remove the cloud property `availability_set` in your [`vm_extensions`](https://bosh.io/docs/azure-cpi.html#resource-pools) if it exists.

    When a VM is in a zone, it can't be in any Availability Set. CPI will raise an error if you have both `availability_zone` and `availability_set` specified for a VM.

1. Add `availability_zone` to cloud_properties of VMs for an existed regional deployment and redeploy CF.

    CPI will do the following things to migrate the VMs and data disks to corresponding zones.

    1. VM will be deleted and recreated in the specified zone.
    
    1. If the VM has a data disk attached, CPI will migrate the data disk to the specified zone when CPI attaches the data disk to it.
    
        CPI will take a snapshot of the data disk, delete the origian data disk, create a new data disk (reuse the disk name) from the snapshot, then delete the snapshot. Finally, CPI will attach the new data disk to the VM.
    
        CPI is careful enough when operating data disks. However, if you see an error during disk migration, you might need to migrate it manually to the zone accordingly (you can get zone number in bosh error log).
    
        * if the data disk is not removed. Since the disk name should not be changed after it is migrated, so typicall migration steps are:
    
          1. take a snapshot of the data disk.
          1. note down the disk name and delete the data disk.
          1. create a new data disk in the specific zone, the new disk should use the same disk name noted down in previous step.
          1. now you should be able to redeploy CF.
          1. validate your CF, and if everything is ok you can delete the snapshot.
    
        * if the data disk is removed, it should have a snapshot available. You need to get the snapshot and disk name from bosh error log, and follow steps c to e in previous condition to do migration.
