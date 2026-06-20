#!/bin/bash

# Script to create a PKG installer for Valentine

# Arguments
INPUT_APP="$1"
OUTPUT_PKG="$2"

# Validate arguments
if [ -z "$INPUT_APP" ] || [ -z "$OUTPUT_PKG" ]; then
    echo "Usage: ./create-pkg-release.sh <path-to-app> <path-to-output-pkg>"
    exit 1
fi

if [ ! -d "$INPUT_APP" ]; then
    echo "Error: Input app directory not found at '$INPUT_APP'"
    exit 1
fi

# Ensure required files exist
if [ ! -f "distribution.xml" ]; then
    echo "Error: distribution.xml not found in the current directory."
    exit 1
fi

if [ ! -f "LICENSE" ]; then
    echo "Error: LICENSE not found in the current directory."
    exit 1
fi

echo "Creating PKG from $INPUT_APP to $OUTPUT_PKG..."

# Create a temporary directory to hold build artifacts
TMP_DIR="build_pkg_tmp"
mkdir -p "$TMP_DIR/Resources/en.lproj"

# Copy the license to the English localization folder
cp LICENSE "$TMP_DIR/Resources/en.lproj/License.txt"

# 1. Create the component package inside the temporary directory
echo "Building component package..."
pkgbuild --component "$INPUT_APP" --install-location "/Applications" "$TMP_DIR/Valentine-component.pkg"

# 2. Build the final interactive package using the modified distribution.xml
echo "Building final interactive package..."
productbuild --distribution distribution.xml --resources "$TMP_DIR/Resources" --package-path "$TMP_DIR" "$OUTPUT_PKG"

# 3. Cleanup temporary artifacts
echo "Cleaning up..."
rm -rf "$TMP_DIR"

echo "Done! Installer created at: $OUTPUT_PKG"
