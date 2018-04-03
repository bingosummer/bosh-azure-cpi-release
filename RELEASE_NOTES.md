Features:

- CPI collects diagnostic metrics. (#374)

  The diagnostic data includes the VM and disk creating/deleting status and performance. This helps us to identify the issues quickly with better accuracy.
  
  You can set `enable_telemetry` in the [Azure CPI global configurations](https://bosh.io/docs/azure-cpi.html#global) to enable/disable the feature. The default value is `true`.

- CPI enables [VM boot diagnostics](https://azure.microsoft.com/en-us/blog/boot-diagnostics-for-virtual-machines-v2/) by default. (#377)

  You can set `enable_vm_boot_diagnostics` in the [Azure CPI global configurations](https://bosh.io/docs/azure-cpi.html#global) to enable/disable the feature. The default value is `true`.

  When it's enabled, the diagnostics logs are automatically saved to a dedicated storage account created by CPI. The log is saved for trouble shooting, even after the VM is deleted by Bosh. We recommend you cleaning up the storage account on a regular basis. For more details, see [the trouble shooting doc](https://github.com/cloudfoundry-incubator/bosh-azure-cpi-release/blob/master/docs/additional-information/troubleshooting.md).

- Support AzureChinaCloud AD as Azure Stack authentication. (#381)

  If you deploy your Azure Stack using Azure China Cloud Active Directory as the identity provider, you need to set `azure_stack.authentication` to `AzureChinaCloudAD` in the [Azure CPI global configurations](https://bosh.io/docs/azure-cpi.html#global).

Fixes:

- Bump azure-core gem to `0.1.14` to fix Azure/azure-storage-ruby#118 (#375)

Documents:

- Added a [document](https://github.com/cloudfoundry-incubator/bosh-azure-cpi-release/tree/master/docs/advanced/configure-cf-external-databases-using-azure-mysql-postgres-service) to configure Cloud Foundry external databases using Azure MySQL/Postgres Service. (#373)

Development:

- Application security group is provisioned using terraform in CI. (#372)
