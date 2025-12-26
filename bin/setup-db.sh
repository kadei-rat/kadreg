#!/bin/bash
set -e
shopt -s nullglob

DB_NAME="${DB_NAME:-kadreg}"
TEST_DB_NAME="${DB_NAME}_test"

setup() {
    echo "setting up $1"
    psql -f database/setup.sql "$1"
    for file in database/migrations/*.sql; do
      echo "  Running $(basename "$file")"
      psql -f "$file" "$1"
    done
}

echo "Setting up databases..."

createdb "$DB_NAME"
createdb "$TEST_DB_NAME"

setup "$DB_NAME"
setup "$TEST_DB_NAME"

echo "Setup complete!"
