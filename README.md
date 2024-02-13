# pg_easy_replicate

[![CI](https://github.com/shayonj/pg_easy_replicate/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/shayonj/pg_easy_replicate/actions/workflows/ci.yaml)
[![Smoke spec](https://github.com/shayonj/pg_easy_replicate/actions/workflows/smoke.yaml/badge.svg?branch=main)](https://github.com/shayonj/pg_easy_replicate/actions/workflows/ci.yaml)
[![Gem Version](https://badge.fury.io/rb/pg_easy_replicate.svg?2)](https://badge.fury.io/rb/pg_easy_replicate)

`pg_easy_replicate` is a CLI orchestrator tool that simplifies the process of setting up [logical replication](https://www.postgresql.org/docs/current/logical-replication.html) between two PostgreSQL databases. `pg_easy_replicate` also supports switchover. After the source (primary database) is fully replicated, `pg_easy_replicate` puts it into read-only mode and via logical replication flushes all data to the new target database. This ensures zero data loss and minimal downtime for the application. This method can be useful for performing minimal downtime (up to <1min, depending) major version upgrades between a Blue/Green PostgreSQL database setup, load testing and other similar use cases.

Battle tested in production at [Tines](https://www.tines.com/) 🚀

![](./assets/mascot.png)

- [Installation](#installation)
- [Requirements](#requirements)
- [Limits](#limits)
- [Usage](#usage)
- [CLI](#cli)
- [Replicating all tables with a single group](#replicating-all-tables-with-a-single-group)
  - [Config check](#config-check)
  - [Bootstrap](#bootstrap)
  - [Bootstrap and Config Check with special user role in AWS or GCP](#bootstrap-and-config-check-with-special-user-role-in-aws-or-gcp)
    - [Config Check](#config-check-1)
    - [Bootstrap](#bootstrap-1)
  - [Start sync](#start-sync)
  - [Stats](#stats)
  - [Performing switchover](#performing-switchover)
- [Replicating single database with custom tables](#replicating-single-database-with-custom-tables)
- [Switchover strategies with minimal downtime](#switchover-strategies-with-minimal-downtime)
  - [Rolling restart strategy](#rolling-restart-strategy)
  - [DNS Failover strategy](#dns-failover-strategy)
- [FAQ](#faq)
  - [Adding internal user to `pg_hba` or pgBouncer `userlist`](#adding-internal-user-to-pg_hba-or-pgbouncer-userlist)
- [Contributing](#contributing)

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
- Ruby 3.0 and later
- Database users should have `SUPERUSER` permissions, or pass in a special user with privileges to create the needed role, schema, publication and subscription on both databases. More on `--special-user-role` section below.
- See more on [FAQ](#faq) below

## Limits

All [Logical Replication Restrictions](https://www.postgresql.org/docs/current/logical-replication-restrictions.html) apply.

## Usage

Ensure `SOURCE_DB_URL` and `TARGET_DB_URL` are present as environment variables in the runtime environment. The URL are of the postgres connection string format. Example:

```bash
$ export SOURCE_DB_URL="postgres://USERNAME:PASSWORD@localhost:5432/DATABASE_NAME"
$ export TARGET_DB_URL="postgres://USERNAME:PASSWORD@localhost:5433/DATABASE_NAME"
```

**Optional**

You can extend the default timeout by setting the following environment variable

```bash
$ export PG_EASY_REPLICATE_STATEMENT_TIMEOUT="10s" # default 5s
```

Any `pg_easy_replicate` command can be run the same way with the docker image as well. As long the container is running in an environment where it has access to both the databases. Example

```bash
docker run -e SOURCE_DB_URL="postgres://USERNAME:PASSWORD@localhost:5432/DATABASE_NAME"  \
  -e TARGET_DB_URL="postgres://USERNAME:PASSWORD@localhost:5433/DATABASE_NAME" \
  -it --rm shayonj/pg_easy_replicate:latest \
  pg_easy_replicate config_check
```

## CLI

```bash
$  pg_easy_replicate
pg_easy_replicate commands:
  pg_easy_replicate bootstrap -g, --group-name=GROUP_NAME    # Sets up temporary tables for information required during runtime
  pg_easy_replicate cleanup -g, --group-name=GROUP_NAME      # Cleans up all bootstrapped data for the respective group
  pg_easy_replicate config_check                             # Prints if source and target database have the required config
  pg_easy_replicate help [COMMAND]                           # Describe available commands or one specific command
  pg_easy_replicate start_sync -g, --group-name=GROUP_NAME   # Starts the logical replication from source database to target database provisioned in the group
  pg_easy_replicate stats  -g, --group-name=GROUP_NAME       # Prints the statistics in JSON for the group
  pg_easy_replicate stop_sync -g, --group-name=GROUP_NAME    # Stop the logical replication from source database to target database provisioned in the group
  pg_easy_replicate switchover  -g, --group-name=GROUP_NAME  # Puts the source database in read only mode after all the data is flushed and written
  pg_easy_replicate version                                  # Prints the version

```

## Replicating all tables with a single group

You can create as many groups as you want for a single database. Groups are just a logical isolation of a single replication.

### Config check

```bash
$ pg_easy_replicate config_check

✅ Config is looking good.
```

### Bootstrap

Every sync will need to be bootstrapped before you can set up the sync between two databases. Bootstrap creates a new super user to perform the orchestration required during the rest of the process. It also creates some internal metadata tables for record keeping.

```bash
$ pg_easy_replicate bootstrap --group-name database-cluster-1 --copy-schema

{"name":"pg_easy_replicate","hostname":"PKHXQVK6DW","pid":21485,"level":30,"time":"2023-06-19T15:51:11.015-04:00","v":0,"msg":"Setting up schema","version":"0.1.0"}
...
```

### Bootstrap and Config Check with special user role in AWS or GCP

If you don't want your primary login user to have `superuser` privileges or you are on AWS or GCP, you will need to pass in the special user role that has the privileges to create role, schema, publication and subscription. This is required so `pg_easy_replicate` can create a dedicated user for replication which is granted the respective special user role to carry out its functionalities.

For AWS the special user role is `rds_superuser`, and for GCP it is `cloudsqlsuperuser`. Please refer to docs for the most up to date information.

**Note**: The user in the connection url must be part of the special user role being supplied.

#### Config Check

```bash
$ pg_easy_replicate config_check --special-user-role="rds_superuser" --copy-schema

✅ Config is looking good.
```

#### Bootstrap

```bash
$ pg_easy_replicate bootstrap --group-name database-cluster-1 --special-user-role="rds_superuser" --copy-schema

{"name":"pg_easy_replicate","hostname":"PKHXQVK6DW","pid":21485,"level":30,"time":"2023-06-19T15:51:11.015-04:00","v":0,"msg":"Setting up schema","version":"0.1.0"}
...
```

### Start sync

Once the bootstrap is complete, you can start the sync. Starting the sync sets up the publication, subscription and performs other minor housekeeping things.

**NOTE**: Start sync by default will drop all indices in the target database for performance reasons. And will automatically re-add the indices during `switchover`. It is turned on by default and you can opt out of this with `--no-recreate-indices-post-copy`

```bash
$ pg_easy_replicate start_sync --group-name database-cluster-1

{"name":"pg_easy_replicate","hostname":"PKHXQVK6DW","pid":22113,"level":30,"time":"2023-06-19T15:54:54.874-04:00","v":0,"msg":"Setting up publication","publication_name":"pger_publication_database_cluster_1","version":"0.1.0"}
...
```

### Stats

You can inspect or watch stats any time during the sync process. The stats give you an idea of when the sync started, current flush/write lag, how many tables are in `replicating`, `copying` or other stages, and more.

You can poll these stats to perform any other after the switchover is done. The stats include a `switchover_completed_at` which is updated once the switch over is complete.

```bash
$ pg_easy_replicate stats --group-name database-cluster-1

{
  "lag_stats": [
    {
      "pid": 66,
      "client_addr": "192.168.128.2",
      "user_name": "jamesbond",
      "application_name": "pger_subscription_database_cluster_1",
      "state": "streaming",
      "sync_state": "async",
      "write_lag": "0.0",
      "flush_lag": "0.0",
      "replay_lag": "0.0"
    }
  ],
  "message_lsn_receipts": [
    {
      "received_lsn": "0/1674688",
      "last_msg_send_time": "2023-06-19 19:56:35 UTC",
      "last_msg_receipt_time": "2023-06-19 19:56:35 UTC",
      "latest_end_lsn": "0/1674688",
      "latest_end_time": "2023-06-19 19:56:35 UTC"
    }
  ],
  "sync_started_at": "2023-06-19 19:54:54 UTC",
  "sync_failed_at": null,
  "switchover_completed_at": null

  ....
```

### Performing switchover

`pg_easy_replicate` doesn't kick off the switchover on its own. When you start the sync via `start_sync`, it starts the replication between the two databases. Once you have had the time to monitor stats and any other key metrics, you can kick off the `switchover`.

`switchover` will wait until all tables in the group are replicating and the delta for lag is <200kb (by calculating the `pg_wal_lsn_diff` between `sent_lsn` and `write_lsn`) and then perform the switch.

Additionally, `switchover` will take care of re-adding the indices (it had removed in `start_sync`) in the target database before hand. Depending on the size of the tables, the recreation of indexes (which happens `CONCURRENTLY`) may take a while. See `start_sync` for more details.

The switch is made by putting the user on the source database in `READ ONLY` mode, so that it is not accepting any more writes and waits for the flush lag to be `0`. It’s up to the user to kick off a rolling restart of their application containers or failover DNS (more on these below in strategies) after the switchover is complete, so that your application isn't sending any read + write requests to the old/source database.

```bash
$ pg_easy_replicate switchover  --group-name database-cluster-1

{"name":"pg_easy_replicate","hostname":"PKHXQVK6DW","pid":24192,"level":30,"time":"2023-06-19T16:05:23.033-04:00","v":0,"msg":"Watching lag stats","version":"0.1.0"}
...
```

## Replicating single database with custom tables

By default all tables are added for replication but you can create multiple groups with custom tables for the same database. Example

```bash

$ pg_easy_replicate bootstrap --group-name database-cluster-1 --copy-schema
$ pg_easy_replicate start_sync --group-name database-cluster-1 --schema-name public --tables "users, posts, events"

...

$ pg_easy_replicate bootstrap --group-name database-cluster-2 --copy-schema
$ pg_easy_replicate start_sync --group-name database-cluster-2 --schema-name public --tables "comments, views"

...
$ pg_easy_replicate switchover  --group-name database-cluster-1
$ pg_easy_replicate switchover  --group-name database-cluster-2
...
```

## Switchover strategies with minimal downtime

For minimal downtime, it'd be best to watch/tail the stats and wait until `switchover_completed_at` is updated with a timestamp. Once that happens you can perform any of the following strategies. Note: These are just suggestions and `pg_easy_replicate` doesn't provide any functionalities for this.

### Rolling restart strategy

In this strategy, you have a change ready to go which instructs your application to start connecting to the new database. Either using an environment variable or similar. Depending on the application type, it may or may not require a rolling restart.

Next, you can set up a program that watches the `stats` and waits until `switchover_completed_at` is reporting as `true`. Once that happens it kicks off a rolling restart of your application containers so they can start making connections to the DNS of the new database.

### DNS Failover strategy

In this strategy, you have a weighted based DNS system (example [AWS Route53 weighted records](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-values-weighted.html)) where 100% of traffic goes to a primary origin and 0% to a secondary origin. The primary origin here is the DNS host for your source database and secondary origin is the DNS host for your target database. You can set up your application ahead of time to interact with the database using DNS from the weighted group.

Next, you can set up a program that watches the `stats` and waits until `switchover_completed_at` is reporting as `true`. Once that happens it updates the weight in the DNS weighted group where 100% of the requests now go to the new/target database. Note: Keeping a low `ttl` is recommended.

## FAQ

### Adding internal user to `pg_hba` or pgBouncer `userlist`

`pg_easy_replicate` sets up a designated user for managing the replication process. In case you handle user permissions through `pg_hba`, it's necessary to modify this list to permit sessions from `pger_su_h1a4fb`. Similarly, with pgBouncer, you'll need to authorize `pger_su_h1a4fb` for login access by including it in the `userlist`.

## Contributing

PRs most welcome. You can get started locally by

- `docker compose down -v && docker compose up --remove-orphans --build`
- Install ruby `3.1.4` using RVM ([instruction](https://rvm.io/rvm/install#any-other-system))
- `bundle exec rspec` for specs
