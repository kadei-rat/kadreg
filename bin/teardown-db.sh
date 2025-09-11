#!/bin/bash
set -e

DB_NAME="${DB_NAME:-kadreg}"
TEST_DB_NAME="${DB_NAME}_test"

echo "WARNING: This will permanently delete the dev and test databases! Are you sure?"
read -p "Type 'YES' to continue: " confirmation

if [ "$confirmation" != "YES" ]; then
    echo "Aborted."
    exit 1
fi

echo "Tearing down databases..."

dropdb "$DB_NAME"
dropdb "$TEST_DB_NAME"

echo "Teardown complete!"
