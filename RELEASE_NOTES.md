Azure CPI starts to use [semantic versioning](https://semver.org/) from `v35.0.0`.

Features:

- Support [service principal with certificate](https://docs.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli?view=azure-cli-latest) #355

- Support ADFS authentication in Azure Stack #355

- Remove the Azure Stack properties `skip_ssl_validation` and `use_http_to_access_storage_account` #354

  Users need to specify CA root certificate (`ca_cert`) so that CPI can verify SSL. #308

- Allow not specifying the network security group (NSG). #356, #357

  If users don't sepcify the NSG in the [`vm_types/vm_extensions`](http://bosh.io/docs/azure-cpi.html#resource-pools), [`network`](http://bosh.io/docs/azure-cpi.html#networks) and [`global configuration`](http://bosh.io/docs/azure-cpi.html#global), then CPI won't associate the NSG at a VM network interface level. Users can still associate the NSG at the subnet level outside of CPI.

Fixes:

- Change the default values of fault domains (FD) and update domains (UD) to 1 for Azure Stack #353

  [Only single FD and UD are supported in Azure Stack](https://docs.microsoft.com/en-us/azure/azure-stack/user/azure-stack-vm-considerations). #350

- The disk is migrated only if the disk name starts with `DATA_DISK_PREFIX` #352

Documents:

- Add documents for Cloud Foundry on Azure Stack #354

- Add documents for using service principal with certificate #355
