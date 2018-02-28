Fixes:

- CPI returns more granulated error messages for asynchronous errors when creating a storage account. (#361)

- When the specified storage account doesn't exist, previously there is a potential race condition when CPI tries to create the storage account. CPI now handles the race condition correctly. (#365)

- Previously exceptions are ignored when creating a storage account. CPI now handles the exceptions correctly. (#365)

Documents:

- Added a document and script to collect deployment error logs. (#369)

- Added a document for the CPI method `calculate_vm_cloud_properties`. (#362)

Developement:

- Refined the development document. (#370)

  - Added how to setup the pipeline

  - BOSH CLI `v2.0.36+` is required to create a release.
