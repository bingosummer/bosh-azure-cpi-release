#!/usr/bin/env bash

set -e

source /etc/profile.d/chruby.sh
chruby ${RUBY_VERSION}

semver=`cat version-semver/number`

pushd bosh-cpi-src > /dev/null
  echo "using bosh CLI version..."
  bosh version

  cpi_release_name="bosh-azure-cpi"

  echo "building CPI release..."
  bosh create release --name ${cpi_release_name} --version ${semver} --with-tarball
popd > /dev/null

mv bosh-cpi-src/dev_releases/${cpi_release_name}/${cpi_release_name}-${semver}.tgz candidate/
