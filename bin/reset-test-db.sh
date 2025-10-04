#!/bin/bash
set -e

echo "Resetting test database..."

run_migrations() {
    echo "Running migrations on $1"
    for file in migrations/*.sql; do
        if [ -f "$file" ]; then
            echo "  Running $(basename "$file")"
            psql -f "$file" "$1"
        fi
    done
}

TEST_DB_NAME="${DB_NAME:-kadreg}_test"

dropdb "$TEST_DB_NAME"
createdb "$TEST_DB_NAME"
run_migrations "$TEST_DB_NAME"

echo "Reset complete!"
