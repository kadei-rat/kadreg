# kadreg

### Prerequisites

- [Erlang](https://www.erlang.org/downloads), the version specified in `.tool-versions`
- [Gleam](https://gleam.run/getting-started/installation/), the version specified in `.tool-versions`
- [PostgreSQL](https://www.postgresql.org/download/), at least version 10.

### First time setup

Set DB_HOST (defaults to localhost), DB_PORT (defaults to 5432), DB_USER, and
DB_PASSWORD environment variables as needed to allow kadreg to access your postgres instance.

Run `./bin/setup-db.sh` to create the database and run migrations.

### Running & testing

```sh
gleam run   # Run the project
gleam test  # Run the tests
```

### Database helpers

- `./bin/setup-db.sh` - creates dev and test databases and runs migrations on both
- `./bin/teardown-db.sh` - drops both databases
- `./bin/reset-db.sh` - drops, creates, and migrates dev and test databases
