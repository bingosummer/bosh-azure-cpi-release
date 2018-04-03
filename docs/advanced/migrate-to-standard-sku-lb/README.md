# Migrate Load Balancer from Basic SKU to Standard SKU

[Standard Load Balancer is a new Load Balancer product for all TCP and UDP applications with an expanded and more granular feature set over Basic Load Balancer](https://docs.microsoft.com/en-us/azure/load-balancer/load-balancer-standard-overview). You can simply configure the cloud property `load_balancer` in your [`vm_extensions`](https://bosh.io/docs/azure-cpi.html#resource-pools) to use the Standard SKU LB. There are downtime during this step because the public IP address is changed when migrating SKUs. This document can help decrease the downtime.

1. Specify the values which are in `<>` in the script `migrate-load-balancer.sh`.

1. Add your own commands to deploy your cloud foundry, normally including `bosh update-cloud-config` and `bosh deploy`.

1. Run the script `migrate-load-balancer.sh`.
