#!/usr/bin/env bash

set -e

source bosh-cpi-src/ci/utils.sh
source /etc/profile.d/chruby.sh
chruby ${RUBY_VERSION}

if [ ! -e director-state/director-state.json ]; then
  echo "director-state.json does not exist, skipping..."
  exit 0
fi

if [ -d "director-state/.bosh" ]; then
  # reuse compiled packages
  cp -r director-state/.bosh $HOME/
fi

pushd director-state > /dev/null
  # Don't exit on failure to delete existing deployments
  set +e
    source director.env

    # teardown deployments against BOSH Director
    echo "deleting all deployments"
    bosh2 deployments | awk '{print $1}' | xargs --no-run-if-empty -n 1 bosh2 -n delete-deployment --force -d
    echo "cleaning up bosh BOSH Director..."
    time bosh2 -n clean-up --all
  set -e

  echo "deleting existing BOSH Director VM..."
  bosh2 -n delete-env --vars-store creds.yml -v director_name=bosh director.yml
popd
