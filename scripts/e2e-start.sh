#!/bin/bash

set -eo pipefail

if [[ -z ${GITHUB_WORKFLOW} ]]; then
  export SECONDARY_SOURCE_DB_URL="postgres://james-bond:james-bond123%407%21%273aaR@source_db/postgres-db"
fi

export SOURCE_DB_URL="postgres://james-bond:james-bond123%407%21%273aaR@localhost:5432/postgres-db"
export TARGET_DB_URL="postgres://james-bond:james-bond123%407%21%273aaR@localhost:5433/postgres-db"
export PGPASSWORD='james-bond123@7!'"'"''"'"'3aaR'

echo "===== Performing Bootstrap and cleanup"
bundle exec bin/pg_easy_replicate bootstrap -g cluster-1 --copy-schema
bundle exec bin/pg_easy_replicate start_sync -g cluster-1 -s public --recreate-indices-post-copy --track-ddl
bundle exec bin/pg_easy_replicate stats -g cluster-1

echo "===== Applying DDL change"
psql $SOURCE_DB_URL -c "ALTER TABLE public.pgbench_accounts ADD COLUMN test_column VARCHAR(255)"

echo "===== Applying DDL changes"
echo "Y" | bundle exec bin/pg_easy_replicate apply_ddl_change -g cluster-1

# Switchover
echo "===== Performing switchover"
bundle exec bin/pg_easy_replicate switchover -g cluster-1
