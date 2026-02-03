#!/bin/bash

# Build script for Lambda function with dependencies

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PACKAGE_DIR="${SCRIPT_DIR}/lambda_package"

echo "Building Lambda package..."
echo "Script directory: $SCRIPT_DIR"
echo "Package directory: $PACKAGE_DIR"

# Clean up old package
if [ -d "$PACKAGE_DIR" ]; then
    echo "Removing old package directory..."
    rm -rf "$PACKAGE_DIR"
fi

# Create package directory
mkdir -p "$PACKAGE_DIR"

# Install dependencies
echo "Installing dependencies..."
pip install -r "${SCRIPT_DIR}/requirements.txt" -t "$PACKAGE_DIR" --quiet

# Copy Lambda function
echo "Copying Lambda function..."
cp "${SCRIPT_DIR}/lambda_function.py" "$PACKAGE_DIR/"

# List package contents
echo "Package contents:"
ls -la "$PACKAGE_DIR" | head -20

echo "✓ Lambda package built successfully"
echo "Package location: $PACKAGE_DIR"
