#!/usr/bin/env bash

# Build DUNE spack environment
# Args:
#     workspace: directory to create spack installation in
#     spack-version: spack version to build with
#     dune-release: dune release tag to use
#     gpg-key: GPG key to sign binaries with

# default arguments
SPACK_VERSION=fnal-v1.2.2
DUNE_RELEASE=main

USAGE="Usage: $0 [-r|--dune-release <release>] [-s|--spack-version <version>] [-k|--gpg-key <key>] -w|--workspace <path>"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--workspace)
      WORKSPACE=$2
      shift
      shift
      ;;
    -s|--spack-version)
      SPACK_VERSION=$2
      shift
      shift
      ;;
    -k|--gpg-key)
      GPG_KEY=$2
      shift
      shift
      ;;
    -r|--dune-release)
      DUNE_RELEASE=$2
      shift
      shift
      ;;
    -h|--help)
      echo $USAGE
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo $USAGE
      exit 1
      ;;
  esac
done

if [[ ! -v WORKSPACE ]]; then
  echo Error: workspace directory not specified!
  echo $USAGE
  exit 1
fi

# configure build environment
SPACK_ROOT=$WORKSPACE/spack
SPACK_ENV=$WORKSPACE/env

DUNE_RELEASE_CONFIGS_DIR=$WORKSPACE/dune-release-configs
DUNE_RELEASE_CONFIGS_REPO=git@github.com:DUNE/dune-release-configs

BUILDCACHE=$WORKSPACE/bc
TMPDIR=$WORKSPACE/tmp
mkdir $TMPDIR

cd $WORKSPACE

wget https://github.com/FNALssi/fermi-spack-tools/raw/refs/heads/$SPACK_VERSION/bin/bootstrap
sh ./bootstrap --with_padding $SPACK_ROOT
source $SPACK_ROOT/setup-env.sh

# add scisoft source mirror
spack mirror add --scope site --type source scisoft_mirror_source \
  https://scisoft.fnal.gov/scisoft/spack-mirror/spack-packages/sources

# clone and set up DUNE development environment
git clone -b $DUNE_RELEASE $DUNE_RELEASE_CONFIGS_REPO $DUNE_RELEASE_CONFIGS_DIR

mkdir $SPACK_ENV
cp $DUNE_RELEASE_CONFIGS_DIR/dune-release.yaml $SPACK_ENV/spack.yaml
spack env activate $SPACK_ENV
spack --disable-locks concretize
spack install --fail-fast

# export to buildcache
if [[ ! -v GPG_KEY ]]; then
  echo "No GPG key specified, skipping publication to buildcache"
  exit 0
fi
spack gpg trust -y $GPG_KEY
spack buildcache push --signed --with-build-dependencies --private $BUILDCACHE
spack gpg publish -d $BUILDCACHE --update-index
spack buildcache update-index $BUILDCACHE
