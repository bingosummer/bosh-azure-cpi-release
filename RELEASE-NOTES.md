Fixes:

- Allow controlling "keep failed vms" functionality in CPI global configuration #332

  The functionality was introduced since [`v24`](https://github.com/cloudfoundry-incubator/bosh-azure-cpi-release/releases/tag/v24), which is for troubleshooting. In `v32+`, you can control the functionality via `keep_failed_vms` in Azure CPI's global configuration. The default value is `false`. More details are in #330.

Development:

- Add a flag to enable/disable the azure application security groups tests in CI #333
