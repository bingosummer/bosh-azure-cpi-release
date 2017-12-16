New Features:

- Support a new CPI method [`info`](https://bosh.io/docs/cpi-api-v1.html#info) #346

  This includes the `stemcell_formats` for `multi-cpi` support.

Fixes:

- Use [azure-storage-ruby 0.12.3-preview](https://github.com/Azure/azure-storage-ruby/releases/tag/v0.12.3) for compatibility with current version of Azure Stack. #347, #349

  In AzureStack 1711 update, the storage data service version is `2015-04-05` which azure-storage-ruby `0.14.0-preview` doesn't support. #345

- Fix an issue of `has_disk?`. #344

  When the managed disk is deleted, `has_disk?` will throw an unexpected error instead of returning `false`. #339
