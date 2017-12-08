New Features:

- Support Availability Zones #331

  - Azure Availability Zones are still in public review. You **MUST** reference this [document](https://docs.microsoft.com/en-us/azure/availability-zones/az-overview) to sign up for the Availability Zones preview.

  - Please reference this [guidance](https://github.com/cloudfoundry-incubator/bosh-azure-cpi-release/tree/master/docs/advanced/availability-zone) to use this new feature in CPI.

- Support a new CPI method `calculate_vm_cloud_properties` #336

  With this feature, [`vm_resources`](https://bosh.io/docs/manifest-v2.html#instance-groups) can be specified in the deployment manifest.

Fixes:

- Sleep 30 seconds before attaching data disk #340

  This is a workaround for the issue #280.

- Vendors ruby-2.4-r3 from bosh-packages/ruby-release #338

- Change the format of user image name #342

  In old format, the user image name length may exceed Azure limits (80) in some region (e.g. `Australia Southeast`). The new format has a shorter name.

- Fix a bug of using ip configuration properties to check whether the network interface is primary #337

Documents:

- Update the guidance for the [bosh-setup template v3.0.0](https://github.com/Azure/azure-quickstart-templates/tree/f6652b0540a3c009f09af111daab143c9b888cea/bosh-setup) #343
