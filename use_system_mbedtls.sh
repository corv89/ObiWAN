#!/bin/sh
# Script to set up ObiWAN to use system-provided mbedTLS libraries
# This is particularly useful for Alpine Linux and other musl-based distributions

# Check if mbedtls is installed
if ! pkg-config --exists mbedtls; then
  echo "ERROR: mbedtls development packages not found"
  echo "Please install them with your package manager:"
  echo "  Alpine: apk add mbedtls-dev"
  echo "  Debian/Ubuntu: apt install libmbedtls-dev"
  echo "  Fedora: dnf install mbedtls-devel"
  exit 1
fi

# Create marker file to indicate system mbedTLS should be used
echo "Creating USE_SYSTEM_MBEDTLS marker file..."
touch USE_SYSTEM_MBEDTLS

echo "========================================================"
echo "System mbedTLS will now be used for building ObiWAN"
echo "To build with system mbedTLS, run:"
echo "  nimble buildall"
echo ""
echo "To revert to using the vendored mbedTLS, simply delete"
echo "the USE_SYSTEM_MBEDTLS file in the project root."
echo "========================================================"