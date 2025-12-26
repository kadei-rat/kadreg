#!/bin/bash
set -e
shopt -s nullglob

echo "Resetting test database..."

setup() {
    echo "setting up $1"
    psql -f database/setup.sql "$1"
    for file in database/migrations/*.sql; do
      echo "  Running $(basename "$file")"
      psql -f "$file" "$1"
    done
}

TEST_DB_NAME="${DB_NAME:-kadreg}_test"

dropdb "$TEST_DB_NAME"
createdb "$TEST_DB_NAME"
setup "$TEST_DB_NAME"

echo "Reset complete!"
