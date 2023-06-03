# pg_easy_replicate

**⚠️ NOTE: This project is currently WIP**

`pg_easy_replicate` is an orchestrator tool that simplifies the process of setting up logical replication between two PostgreSQL databases. It comes with a CLI and a web interface. `pg_easy_replicate` also supports switchover. After the source (primary database is fully replicating, `pg_easy_replicate` puts it into read-only mode and via logical replication flushes all data to the new target database. This ensures zero data loss and minimal downtime for the application. This method can be useful for upgrading between major version PostgreSQL databases, load testing with blue/green database setup and other similar use cases.

- [pg_easy_replicate](#pg-easy-replicate)
  - [Installation](#installation)
  - [Requirements](#requirements)
  - [Limits](#limits)
  - [Usage](#usage)
  - [Config check](#config-check)
    - [Bootstrap](#bootstrap)
    - [Preliminary checks](#preliminary-checks)
    - [Start replication](#start-replication)
      - [Groups](#groups)
      - [Configuration](#configuration)
    - [Stats](#stats)
    - [Perform switchover](#perform-switchover)
    - [With bi-directional replication](#with-bi-directional-replication)

## Installation

Add this line to your application's Gemfile:

```ruby
gem "pg_easy_replicate"
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install pg_easy_replicate

This will include all dependencies accordingly as well. Make sure the following requirements are satisfied.

Or via Docker:

    docker pull shayonj/pg_easy_replicate:latest

https://hub.docker.com/r/shayonj/pg_easy_replicate

## Requirements

- PostgreSQL 10 and later
- Ruby 2.7 and later
- Database user should have permissions for `SUPERUSER`

## Limits

All [Logical Replication Restrictions](https://www.postgresql.org/docs/current/logical-replication-restrictions.html) apply.

## Usage

Ensure `SOURCE_DB_URL` and `TARGET_DB_URL` are present as environment variables in the runtime environment. The URL are of the postgres connection string format. Example:

```bash
$ export SOURCE_DB_URL="postgres://USERNAME:PASSWORD@localhost:5432/DATABASE_NAME"
$ export TARGET_DB_URL="postgres://USERNAME:PASSWORD@localhost:5433/DATABASE_NAME"
```

Any `pg_easy_replicate` command can be run the same way with the docker image as well. As long the container is running in an environment where it has access to both the databases. Example

```bash
docker run -it --rm shayonj/pg_easy_replicate:latest \
  -e SOURCE_DB_URL="postgres://USERNAME:PASSWORD@localhost:5432/DATABASE_NAME" \
  -e TARGET_DB_URL="postgres://USERNAME:PASSWORD@localhost:5433/DATABASE_NAME" \
  pg_easy_replicate config_check
```

## Config check

```bash
$ pg_easy_replicate help config_check

Usage:
  pg_easy_replicate config_check

Prints if source and target database have the required config
```

```bash
$ pg_easy_replicate config_check

✅ Config is looking good.
```

### Bootstrap

### Preliminary checks

### Start replication

#### Groups

#### Configuration

### Stats

### Perform switchover

### With bi-directional replication
