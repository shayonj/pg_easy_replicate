#!/bin/bash

set -euo pipefail

export VERSION=$1
echo "VERSION: ${VERSION}"

echo "=== Building Gem ===="
gem build pg_easy_replicate.gemspec

echo "=== Pushing gem ===="
gem push pg_easy_replicate-"$VERSION".gem

echo "=== Sleeping for 15s ===="
sleep 15

echo "=== Pushing tags to github ===="
git tag v"$VERSION"
git push origin --tags

echo "=== Cleaning up ===="
rm pg_easy_replicate-"$VERSION".gem
