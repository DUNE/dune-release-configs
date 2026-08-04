#!/usr/bin/env bash

#  Publish DUNE environment to CVMFS
#
#  Args:
#      build_index: Jenkins build process index to install from
#      build_process: Jenkins build process to use
#      env_name: Name of installed spack environment
#      spack_instance: Spack instance to use

# default arguments
BUILD_INDEX=0
BUILD_PROCESS=dune-spack-build
ENV_NAME=none
SPACK_INSTANCE=/cvmfs/dune.opensciencegrid.org/spack/v1.1.1

# parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--build-index)
      BUILD_INDEX=$2
      shift
      shift
      ;;
    -b|--build-process)
      BUILD_PROCESS=$2
      shift
      shift
      ;;
    -e|--env-name)
      ENV_NAME=$2
      shift
      shift
      ;;
    -s|--spack-instance)
      SPACK_INSTANCE=$2
      shift
      shift
      ;;
    -h|--help)
      echo "Usage: $0 -i|--build-index <index> -e|--env-name <name> [-b|--build-process <process>] [-s|--spack-instance <path>] [-v|--verbose]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# ensure arguments are valid
if (( $BUILD_INDEX < 1 )); then
  echo "Error: Must specify a build index greater than 0."
  exit 1
fi
if [[ "$ENV_NAME" == "none" ]]; then
  echo "Error: Must specify a name for the installed environment,"
  exit 1
fi

# install environment
BUILD_ARTIFACT=https://buildmaster.fnal.gov/buildmaster/job/$BUILD_PROCESS/$BUILD_INDEX/artifact
source $SPACK_INSTANCE/setup-env.sh
cd $SPACK_ROOT
git pull
spack repo update
wget $BUILD_ARTIFACT/env/spack.lock
spack env create $ENV_NAME spack.lock
rm spack.lock
spack env activate $ENV_NAME
spack mirror add --scope site --type binary dune $BUILD_ARTIFACT/bc
spack install --cache-only --include-build-deps
rm $SPACK_ENV/.spack-env/view/.cvmfscatalog
touch $SPACK_ENV/.cvmfscatalog
spack mirror remove dune

