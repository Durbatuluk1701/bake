#!/bin/bash

# Quit early if any command fails
set -e
# Quit early if any variable is unset
set -u

# This script takes a single argument from the command line (the architecture which is either "amd64", "i386" or "arm64" or something else that we CANT HANDLE) and installs cakeml.
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <architecture>"
    exit 1
fi

ARCHITECTURE=$1

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

# Now we get the asset from the latest release of CakeML
RELEASE_URL="https://github.com/CakeML/cakeml/releases/latest/download/${ASSET}"

# Download the asset
echo "Downloading CakeML from $RELEASE_URL..."
# Hide the output of the curl command
curl -L -o "$ASSET" "$RELEASE_URL" >/dev/null 2>&1

# Unpack the asset
echo "Unpacking $ASSET..."
tar -xzf "$ASSET"

# Move into the asset directory
ASSET_DIR="${ASSET%.tar.gz}"
cd "$ASSET_DIR"

# Build CakeML
echo "Building CakeML..."
make

# Copy it back to the original directory
cd ..
cp "$ASSET_DIR"/cake .