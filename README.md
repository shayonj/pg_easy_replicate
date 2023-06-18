# pg_easy_replicate

**⚠️ NOTE: This project is currently WIP**

`pg_easy_replicate` is a CLI orchestrator tool that simplifies the process of setting up logical replication between two PostgreSQL databases. `pg_easy_replicate` also supports switchover. After the source (primary database is fully replicating, `pg_easy_replicate` puts it into read-only mode and via logical replication flushes all data to the new target database. This ensures zero data loss and minimal downtime for the application. This method can be useful for upgrading between major version PostgreSQL databases, load testing with blue/green database setup and other similar use cases.

- [Installation](#installation)
- [Requirements](#requirements)
- [Limits](#limits)
- [Usage](#usage)
  - [Getting started](#getting-started)
  - [Config check](#config-check)
  - [Bootstrap](#bootstrap)
  - [Start replication](#start-replication)
  - [Stats](#stats)
  - [Perform switchover](#perform-switchover)
- [Replicating single database with multiple groups](#replicating-single-database-with-multiple-groups)
- [Performing switchover](#performing-switchover)
- [Switchover strategies with minimal downtime](#switchover-strategies-with-minimal-downtime)
  - [Rolling restart strategy](#rolling-restart-strategy)
  - [DNS Failover strategy](#dns-failover-strategy)
- [Bi-directional replication](#bi-directional-replication)

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
- Both databases should have the same schema

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

### Getting started

```bash
# Ensure everything is in order
$ pg_easy_replicate config_check
✅ Config is looking good.

# Bootstrap - this is required for every group
$ pg_easy_replicate bootstrap --group-name database-cluster-1
...

# Start the sync
$ pg_easy_replicate start_sync --group-name database-cluster-1 --schema-name public --tables "users, posts, events"

# Watch the stats
$ pg_easy_replicate stats --group-name database-cluster-1 --watch

# Switchover when ready
$ pg_easy_replicate switchover --group-name database-cluster-1
```

### Config check

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

```bash
$ pg_easy_replicate help bootstrap

Usage:
  pg_easy_replicate bootstrap -g, --group-name=GROUP_NAME

Options:
  -g, --group-name=GROUP_NAME  # Name of the group to provision

Sets up temporary tables for information required during runtime
```

### Start replication

```bash
$ pg_easy_replicate help start_sync

Usage:
  pg_easy_replicate start_sync -g, --group-name=GROUP_NAME

Options:
  -g, --group-name=GROUP_NAME      # Name of the grouping for this collection of source and target DB
  -s, [--schema-name=SCHEMA_NAME]  # Name of the schema tables are in, only required if passsing list of tables
  -t, [--tables=TABLES]            # Comma separated list of table names. Default: All tables

Starts the logical replication from source database to target database provisioned in the group
```

### Stats

```bash
$ pg_easy_replicate help stats
Usage:
  pg_easy_replicate stats  -g, --group-name=GROUP_NAME

Options:
  -g, --group-name=GROUP_NAME  # Name of the group previously provisioned
  -w, [--watch=WATCH]          # Tail the stats

Prints the statistics in JSON for the group
```

### Perform switchover

```bash
$ pg_easy_replicate help switchover

Usage:
  pg_easy_replicate switchover  -g, --group-name=GROUP_NAME

Options:
  -g, --group-name=GROUP_NAME            # Name of the group previously provisioned
  -l, [--lag-delta-size=LAG_DELTA_SIZE]  # The size of the lag to watch for before switchover. Default 200KB.

Puts the source database in read only mode after all the data is flushed and written
```

## Replicating single database with multiple groups

By default all tables are added for replication but you can create multiple groups with custom tables for the same database. Example

```bash

$ pg_easy_replicate bootstrap --group-name database-cluster-1
$ pg_easy_replicate start_sync --group-name database-cluster-1 --schema-name public --tables "users, posts, events"

...

$ pg_easy_replicate bootstrap --group-name database-cluster-2
$ pg_easy_replicate start_sync --group-name database-cluster-2 --schema-name public --tables "comments, views"

...
$ pg_easy_replicate switchover  --group-name database-cluster-1
$ pg_easy_replicate switchover  --group-name database-cluster-2
...
```

## Performing switchover

`pg_easy_replicate` doesn't kick off the switchover on its own. When you start the sync via `start_sync`, it starts the replicating between the two databases. Once you have had the time to monitor stats and any other key metrics, you can kick off the `switchover`.

`switchover` will wait until all tables in the group are replicating and the delta for lag is <200kb (between the LSN for write and flush lag) and then perform the switch.

The switch is made by putting the user on the source database in `READ ONLY` mode, so that it is not accepting any more writes and waits for the flush lag to be 0. It is up to you to kick of a rolling restart of your application containers or failover DNS (more on this below in strategies) after the switchover is complete, so that your application isn't sending any read/write requests to the old/source database.

## Switchover strategies with minimal downtime

For minimal downtime, it'd be best to watch/tail the stats and wait until `switchover_complete` is reporting as `true`. Once that happens you can perform any of the following strategies. Note: These are just suggestions and `pg_easy_replicate` doesn't provide any functionalities for this.

### Rolling restart strategy

In this strategy, you have a change ready to go which instructs your application to start connecting to the new database. Either using an environment variable or similar. Depending on the application type, it may or may not require a rolling restart.

Next, you can set up a program that watches the `stats` and waits until `switchover_complete` is reporting as `true`. Once that happens it kicks of a rolling restart of your application containers so they can start making connections to the DNS of the new database.

### DNS Failover strategy

TBD

## Bi-directional replication

TBD
