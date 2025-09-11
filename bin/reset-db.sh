#!/bin/bash
set -e

echo "Resetting databases..."

./bin/teardown-db.sh
./bin/setup-db.sh

echo "Reset complete!"
