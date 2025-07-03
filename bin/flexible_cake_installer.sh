#!/bin/bash

# Quit early if any command fails
set -e
# Quit early if any variable is unset
set -u

# This script takes a single argument from the command line (the architecture which is either "amd64", "i386" or "arm64" or something else that we CANT HANDLE) and installs cakeml.
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <architecture> <tarball_dir>"
  exit 1
fi

ARCHITECTURE=$1
TARBALL_DIR=$2

case "$ARCHITECTURE" in
  amd64)
    echo "Installing CakeML for amd64 architecture..."
    # Add commands to install CakeML for amd64
    ASSET="cake-x64-64.tar.gz"
    ;;
  i386)
    echo "Installing CakeML for i386 architecture..."
    # Add commands to install CakeML for i386
    ASSET="cake-x64-32.tar.gz"
    ;;
  arm64)
    echo "Installing CakeML for arm64 architecture..."
    # Add commands to install CakeML for arm64
    ASSET="cake-arm8-64.tar.gz"
    ;;
  *)
    echo "Unsupported architecture: $ARCHITECTURE"
    echo "Supported architectures are: amd64, i386, arm64"
    exit 1
    ;;
esac

# Unpack the asset
echo "Unpacking $ASSET..."
tar -xzf "$TARBALL_DIR/$ASSET"

# Move into the asset directory
ASSET_DIR="${ASSET%.tar.gz}"
cd "$ASSET_DIR"

# Build CakeML
echo "Building CakeML..."
make

# Copy "cake" and "basis_ffi.c" back to the original directory
cd ..
cp "$ASSET_DIR"/cake .
cp "$ASSET_DIR"/basis_ffi.c .