V21

New Features:

* Support [managed disks](https://azure.microsoft.com/en-us/services/managed-disks/). Please reference the [guidance](https://github.com/cloudfoundry-incubator/bosh-azure-cpi-release/tree/master/docs/advanced/managed-disks) on how to deploy a new deployment, or migrate an existing deployment, utilizing the new Managed Disks Service on Azure.

  Below github issues are fixed with managed disks.
  
  * [#228: Can we support managed disks?](https://github.com/cloudfoundry-incubator/bosh-azure-cpi-release/issues/228)
  * [#225: Stripe storage account placement across each VM in an availability set](https://github.com/cloudfoundry-incubator/bosh-azure-cpi-release/issues/225)
  * [#178: Avoid using storage account tables to keep track of copying process](https://github.com/cloudfoundry-incubator/bosh-azure-cpi-release/issues/178)
  * [#116: user should be able to set storage_account_name on a persistent disk](https://github.com/cloudfoundry-incubator/bosh-azure-cpi-release/issues/116)
  * [#68: CID of VMs is not well named](https://github.com/cloudfoundry-incubator/bosh-azure-cpi-release/issues/68)

Improvements:

* Upgrade azure-storage-ruby to v0.11.5.

  Please see [release notes](https://github.com/Azure/azure-storage-ruby/releases/tag/v0.11.5) of azure-storage-ruby v0.11.5

* Auto retry when the connection to Azure AD or ARM is reset because of `OpenSSL::SSL::SSLError` or `OpenSSL::X509::StoreError`.
