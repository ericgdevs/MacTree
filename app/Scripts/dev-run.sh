#!/bin/bash
# Dev run script for MacTree

set -e

cd "$(dirname "$0")/.."

echo "Building MacTree..."
swift build

echo "Running MacTree..."
.build/debug/MacTree
