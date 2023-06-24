#!/bin/bash

set -eo pipefail

if [[ -z ${GITHUB_WORKFLOW} ]]; then
  export SECONDARY_SOURCE_DB_URL="postgres://jamesbond:jamesbond123%407%21%273aaR@source_db/postgres"
fi

export SOURCE_DB_URL="postgres://jamesbond:jamesbond123%407%21%273aaR@localhost:5432/postgres"
export TARGET_DB_URL="postgres://jamesbond:jamesbond123%407%21%273aaR@localhost:5433/postgres"
export PGPASSWORD='jamesbond123@7!'"'"'3aaR'

pgbench --initialize -s 5 --foreign-keys --host localhost -U jamesbond -d postgres

pg_dump --schema-only --host localhost -U jamesbond -d postgres >schema.sql
cat schema.sql | psql --host localhost -U jamesbond -d postgres -p 5433
rm schema.sql

bundle exec bin/pg_easy_replicate config_check
