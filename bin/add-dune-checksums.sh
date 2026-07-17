#!/usr/bin/env bash

#  Add versions to DUNE package spack recipes
#
#  Args:
#      dunesw-version: dunesw suite version to add
#      duneanaobj-version: duneanaobj version to add
#      dunedaqdataformats-version: dunedaqdataformats version to add
#      dunedetdataformats-version: dunedetdataformats version to add
#      dunepdlegacy-version: dunepdlegacy version to add

# default arguments
DUNESW_VERSION=none
DUNEANAOBJ_VERSION=none
DUNEDAQDATAFORMATS_VERSION=none
DUNEDETDATAFORMATS_VERSION=none
DUNEPDLEGACY_VERSION=none

# parse arguments
USAGE="Usage: $0 [-d|--dunesw-version <version>] [--duneanaobj-version <version>] [--dunedaqdataformats-version <version>] [--dunedetdataformats-version <version>] [--dunepdlegacy-version <version>] [-v|--verbose]"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dunesw-version)
      DUNESW_VERSION=$2
      shift
      shift
      ;;
    --duneanaobj-version)
      DUNEANAOBJ_VERSION=$2
      shift
      shift
      ;;
    --dunedaqdataformats-version)
      DUNEDAQDATAFORMATS_VERSION=$2
      shift
      shift
      ;;
    --dunedetdataformats-version)
      DUNEDETDATAFORMATS_VERSION=$2
      shift
      shift
      ;;
    --dunepdlegacy-version)
      DUNEPDLEGACY_VERSION=$2
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

# DUNE suite packages
if [[ $DUNESW_VERSION != none ]]; then
  for pkg in duneana dunecalib dunecore dunedataprep duneexamples duneopdet \
             duneprototypes dunereco dunesim dunesw duneutil protoduneana; do
    spack checksum -a $pkg $DUNESW_VERSION
  done
fi

# duneanaobj version
if [[ $DUNEANAOBJ_VERSION != none ]]; then
  spack checksum -a duneanaobj $DUNEANAOBJ_VERSION
fi

# dunedaqdataformats version
if [[ $DUNEDAQDATAFORMATS_VERSION != none ]]; then
  spack checksum -a dunedaqdataformats $DUNEDAQDATAFORMATS_VERSION
fi

# dunedetdataformats version
if [[ $DUNEDETDATAFORMATS_VERSION != none ]]; then
  spack checksum -a dunedetdataformats $DUNEDETDATAFORMATS_VERSION
fi

# dunepdlegacy version
if [[ $DUNEPDLEGACY_VERSION != none ]]; then
  spack checksum -a dunepdlegacy $DUNEPDLEGACY_VERSION
fi

