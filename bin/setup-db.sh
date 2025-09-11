#!/bin/bash
set -e

DB_NAME="${DB_NAME:-kadreg}"
TEST_DB_NAME="${DB_NAME}_test"

run_migrations() {
    echo "Running migrations on $1"
    for file in migrations/*.sql; do
        if [ -f "$file" ]; then
            echo "  Running $(basename "$file")"
            psql -f "$file" "$1"
        fi
    done
}

echo "Setting up databases..."

createdb "$DB_NAME"
createdb "$TEST_DB_NAME"

run_migrations "$DB_NAME"
run_migrations "$TEST_DB_NAME"

echo "Setup complete!"
