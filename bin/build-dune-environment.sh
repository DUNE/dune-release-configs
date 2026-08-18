#!/usr/bin/env bash

if [[ ! -v WORKSPACE ]]; then
  echo Error: you must export the WORKSPACE enviroment variable!
  exit 1
fi

# SPACK_REPO=https://github.com/FNALssi/spack.git
# SPACK_VERSION=fnal-v1.1.1
SPACK_REPO=https://github.com/spack/spack.git
SPACK_VERSION=v1.2.2
SPACK_ROOT=$WORKSPACE/spack
SPACK_ENV=$WORKSPACE/env

FERMI_SPACK_TOOLS_VERSION=main

DUNE_RELEASE_CONFIGS_DIR=$WORKSPACE/dune-release-configs
DUNE_RELEASE_CONFIGS_REPO=git@github.com:DUNE/dune-release-configs
DUNE_RELEASE_CONFIGS_VERSION=main

GPG_PUBLIC_KEY=FD371B683264E2F38358BE0A759572C110798CF6

BUILDCACHE=$WORKSPACE/bc

TMPDIR=$WORKSPACE/tmp
mkdir $TMPDIR

cd $WORKSPACE

wget https://github.com/FNALssi/fermi-spack-tools/raw/refs/heads/$FERMI_SPACK_TOOLS_VERSION/bin/bootstrap
sh ./bootstrap --with_padding --spack_repo $SPACK_REPO --spack_release $SPACK_VERSION $SPACK_ROOT
source $SPACK_ROOT/setup-env.sh

# add scisoft source mirror
spack mirror add --scope site --type source scisoft_mirror_source \
  https://scisoft.fnal.gov/scisoft/spack-mirror/spack-packages/sources

# clone and set up DUNE development environment
if [[ -d $DUNE_RELEASE_CONFIGS_DIR ]]; then
  git -C $DUNE_RELEASE_CONFIGS_DIR pull
else
  git clone -b $DUNE_RELEASE_CONFIGS_VERSION \
               $DUNE_RELEASE_CONFIGS_REPO \
               $DUNE_RELEASE_CONFIGS_DIR
fi

mkdir $SPACK_ENV
cp $DUNE_RELEASE_CONFIGS_DIR/dune-release.yaml $SPACK_ENV/spack.yaml
spack env activate $SPACK_ENV
spack --disable-locks concretize
spack install --fail-fast

# export to buildcache
spack gpg trust $V_GPG_KEY
spack buildcache push -k $GPG_PUBLIC_KEY \
  --with-build-dependencies --private $BUILDCACHE
spack gpg publish -d $BUILDCACHE --update-index $GPG_PUBLIC_KEY
spack buildcache update-index $BUILDCACHE

