Features:

- CPI turns off diagnostics metrics and [VM boot diagnostics](https://azure.microsoft.com/en-us/blog/boot-diagnostics-for-virtual-machines-v2/) by default. (#400)

  Collecting diagnotics data should be opt-in, not opt-out. #399.

- CPI supports enabling [IP forwarding]((https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-network-interface#enable-or-disable-ip-forwarding)) for VM network interface. (#382)

  By default, IP forwarding is disabled. To enable it, you can set `ip_forwarding` in [VM type/extension](https://bosh.io/docs/azure-cpi/#resource-pools) or [network configuration](https://bosh.io/docs/azure-cpi/#dynamic-network-or-manual-network) to `true`. The `ip_forwarding` in VM type/extension can override the equivalent option in the network configuration.

Fixes:

- When enabling diagnostics metrics, one of the VMs takes longer time than others because CPI is collecting the metrics. Now CPI doesn't wait for collecting metrics. (#394)

- `Premium_LRS` is used as the disk type if instance type is the series B, Dsv3, Esv3 and Ls. (#389)

- When creating storage account, CPI will wait until its provisioning state becomes succeeded. (#387)

- Update Active Directory Endpoint of Azure USGovernment. (#391)

- Add EOFError as one of the retryable network errors. (#393)

Documents:

- Update CPI global configurations for Azure Stack. (#397)

Development:

- Create standard sku public ip using terraform in CI. (#390)

- Use master branch of bosh-acceptance-tests for CI. (#390)
