#!/usr/bin/env bash

set -e

: ${AZURE_ENVIRONMENT:?}
: ${AZURE_CLIENT_ID:?}
: ${AZURE_CLIENT_SECRET:?}
: ${AZURE_TENANT_ID:?}
: ${AZURE_GROUP_NAME:?}
: ${AZURE_DEFAULT_SECURITY_GROUP:?}
: ${AZURE_VNET_NAME_FOR_BATS:?}
: ${BATS_FIRST_NETWORK:?}
: ${BATS_SECOND_NETWORK:?}
: ${STEMCELL_NAME:?}
: ${BAT_INFRASTRUCTURE:?}
: ${BAT_NETWORKING:?}
: ${BAT_RSPEC_FLAGS:?}

azure login --environment ${AZURE_ENVIRONMENT} --service-principal -u ${AZURE_CLIENT_ID} -p ${AZURE_CLIENT_SECRET} --tenant ${AZURE_TENANT_ID}
azure config mode arm

BATS_PUBLIC_IP=$(azure network public-ip show ${AZURE_GROUP_NAME} AzureCPICI-cf-bats --json | jq '.ipAddress' -r)
echo $BATS_PUBLIC_IP

source bosh-cpi-src/ci/utils.sh
source /etc/profile.d/chruby.sh
chruby ${RUBY_VERSION}

mkdir -p bats-config
bosh2 int \
  -v stemcell_name=${STEMCELL_NAME} \
  -v resource_group_name=${AZURE_GROUP_NAME} \
  -v bats_public_ip=${BATS_PUBLIC_IP} \
  -v default_security_group=${AZURE_DEFAULT_SECURITY_GROUP} \
  -v vnet_name=${AZURE_VNET_NAME_FOR_BATS} \
  -v bats_first_network=${BATS_FIRST_NETWORK} \
  -v bats_second_network=${BATS_SECOND_NETWORK} \
  pipelines/azure/assets/bats/bats-spec.yml > bats-config/bats-config.yml
cat bats-config/bats-config.yml

source director-state/director.env
export BAT_PRIVATE_KEY="$( creds_path /jumpbox_ssh/private_key )"
export BAT_DNS_HOST="${BOSH_ENVIRONMENT}"
export BAT_STEMCELL=$(realpath stemcell/*.tgz)
export BAT_DEPLOYMENT_SPEC=$(realpath bats-config/bats-config.yml)
export BAT_BOSH_CLI=$(which bosh2)

ssh_key_path=/tmp/bat_private_key
echo "$BAT_PRIVATE_KEY" > $ssh_key_path
chmod 600 $ssh_key_path
export BOSH_GW_PRIVATE_KEY=$ssh_key_path

pushd bats
  echo "Running BATs..."
  bundle install
  bundle exec rspec spec $BAT_RSPEC_FLAGS
popd
