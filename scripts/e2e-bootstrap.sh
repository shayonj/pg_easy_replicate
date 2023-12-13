#!/bin/bash

set -eo pipefail

if [[ -z ${GITHUB_WORKFLOW} ]]; then
  export SECONDARY_SOURCE_DB_URL="postgres://james-bond:james-bond123%407%21%273aaR@source_db/postgres-db"
fi

export SOURCE_DB_URL="postgres://james-bond:james-bond123%407%21%273aaR@localhost:5432/postgres-db"
export TARGET_DB_URL="postgres://james-bond:james-bond123%407%21%273aaR@localhost:5433/postgres-db"
export PGPASSWORD='james-bond123@7!'"'"'3aaR'

pgbench --initialize -s 5 --foreign-keys --host localhost -U james-bond -d postgres-db

bundle exec bin/pg_easy_replicate config_check --copy-schema
