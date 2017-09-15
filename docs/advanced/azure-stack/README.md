# Deploy Cloud Foundry on Azure Stack

[Microsoft Azure Stack](https://azure.microsoft.com/en-us/overview/azure-stack/) is a hybrid cloud platform that lets you provide Azure services from your datacenter. Learn [how to deploy Azure Stack and offer services](https://docs.microsoft.com/en-us/azure/azure-stack/).

You need to update the [global configurations](http://bosh.io/docs/azure-cpi.html#global). Set the `environment` to `AzureStack` and configure the `azure_stack` properties.

## Authentication

Azure Stack uses either Azure Active Directory (AAD) or Active Directory Federation Services (AD FS) as an identity provider.

### Azure Active Directory

Please specify the authentication to `AzureAD`, and provide the [service principal with password](../use-service-principal-with-certificate/) (`tenant_id`, `client_id` and `client_secret`).

```
azure:
  environment: AzureStack
  tenant_id: <TENANT-ID>
  client_id: <CLIENT-ID>
  client_secret: <CLIENT-SECRET>
  azure_stack:
    authentication: AzureAD
```

### Active Directory Federation Services

Please specify the authentication to `ADFS`, and provide the [service principal with certificate](../use-service-principal-with-certificate/) (`tenant_id`, `client_id` and `certificate`).

```
azure:
  environment: AzureStack
  tenant_id: <TENANT-ID>
  client_id: <CLIENT-ID>
  certificate: <CERTIFICATE>
  azure_stack:
    authentication: ADFS
```

## Provide CA Cert

If you used a self-signed root certificate when deploying Azure Stack, you need to specify it in the [global configurations](http://bosh.io/docs/azure-cpi.html#global) so that CPI can verify and establish the https connection with Azure Stack endpoints. The Azure Stack CA root certificate is available on the development kit and on a tenant virtual machine that is running within the development kit environment. Sign in to your development kit or the tenant virtual machine and run the following Powershell script to export the Azure Stack root certificate in PEM format:

```
$label = "AzureStackSelfSignedRootCert"
Write-Host "Getting certificate from the current user trusted store with subject CN=$label"
$root = Get-ChildItem Cert:\CurrentUser\Root | Where-Object Subject -eq "CN=$label" | select -First 1
if (-not $root)
{
    Log-Error "Cerficate with subject CN=$label not found"
    return
}

Write-Host "Exporting certificate"
Export-Certificate -Type CERT -FilePath root.cer -Cert $root

Write-Host "Converting certificate to PEM format"
certutil -encode root.cer root.pem
```

Please specify the `ca_cert` in the global configuration.

```
azure:
  environment: AzureStack
  azure_stack:
    ca_cert: |-
      -----BEGIN CERTIFICATE-----
      MII...
      -----END CERTIFICATE-----
```
