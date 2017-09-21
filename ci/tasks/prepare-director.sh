#!/usr/bin/env bash

set -e

: ${AZURE_ENVIRONMENT:?}
: ${AZURE_SUBSCRIPTION_ID:?}
: ${AZURE_CLIENT_ID:?}
: ${AZURE_CLIENT_SECRET:?}
: ${AZURE_TENANT_ID:?}
: ${AZURE_DEFAULT_GROUP_NAME:?}
: ${AZURE_ADDITIONAL_GROUP_NAME:?}
: ${AZURE_VNET_NAME_FOR_BATS:?}
: ${AZURE_BOSH_SUBNET_NAME:?}
: ${AZURE_DEFAULT_SECURITY_GROUP:?}
: ${AZURE_USE_MANAGED_DISKS:?}
: ${OPTIONAL_OPS_FILE:?}

source bosh-cpi-src/ci/utils.sh

azure login --environment ${AZURE_ENVIRONMENT} --service-principal -u ${AZURE_CLIENT_ID} -p ${AZURE_CLIENT_SECRET} --tenant ${AZURE_TENANT_ID}
azure config mode arm

DIRECTOR_PIP=$(azure network public-ip show ${AZURE_ADDITIONAL_GROUP_NAME} AzureCPICI-bosh --json | jq '.ipAddress' -r)

bosh2 int \
  -o bosh-deployment/azure/cpi.yml \
  -o bosh-deployment/misc/powerdns.yml \
  -o bosh-deployment/jumpbox-user.yml \
  -o pipelines/shared/assets/ops/custom-releases.yml \
  -o pipelines/azure/assets/ops/custom-cpi-release.yml \
  $( echo ${OPTIONAL_OPS_FILE} ) \
  -v bosh_release_uri="file://$(echo bosh-release/*.tgz)" \
  -v stemcell_uri="file://$(echo stemcell/*.tgz)" \
  -v cpi_release_uri="file://$(echo cpi-release/*.tgz)" \
  -v director_name=bosh \
  -v dns_recursor_ip=8.8.8.8 \
  bosh-deployment/bosh.yml > /tmp/director.0.yml

if [ "${AZURE_USE_MANAGED_DISKS}" == "true" ]; then
  bosh2 int \
    -o bosh-deployment/azure/use-managed-disks.yml \
    /tmp/director.0.yml > /tmp/director.1.yml
else
  bosh2 int \
    -v storage_account_name=${AZURE_STORAGE_ACCOUNT_NAME} \
    /tmp/director.0.yml > /tmp/director.1.yml
fi

bosh2 int \
  -v external_ip=${DIRECTOR_PIP} \
  -v internal_cidr=10.0.0.0/24 \
  -v internal_gw=10.0.0.1 \
  -v internal_ip=10.0.0.4 \
  -v vnet_name=${AZURE_VNET_NAME_FOR_BATS} \
  -v subnet_name=${AZURE_BOSH_SUBNET_NAME} \
  -v environment=${AZURE_ENVIRONMENT} \
  -v subscription_id=${AZURE_SUBSCRIPTION_ID} \
  -v tenant_id=${AZURE_TENANT_ID} \
  -v client_id=${AZURE_CLIENT_ID} \
  -v client_secret=${AZURE_CLIENT_SECRET} \
  -v resource_group_name=${AZURE_DEFAULT_GROUP_NAME} \
  -v additional_resource_group_name=${AZURE_ADDITIONAL_GROUP_NAME} \
  -v default_security_group=${AZURE_DEFAULT_SECURITY_GROUP} \
  /tmp/director.1.yml > director-config/director.yml

cat director-config/director.yml
