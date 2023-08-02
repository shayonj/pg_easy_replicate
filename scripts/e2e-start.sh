#!/bin/bash

set -eo pipefail

if [[ -z ${GITHUB_WORKFLOW} ]]; then
  export SECONDARY_SOURCE_DB_URL="postgres://james-bond:james-bond123%407%21%273aaR@source_db/postgres"
fi

export SOURCE_DB_URL="postgres://james-bond:james-bond123%407%21%273aaR@localhost:5432/postgres"
export TARGET_DB_URL="postgres://james-bond:james-bond123%407%21%273aaR@localhost:5433/postgres"
export PGPASSWORD='james-bond123@7!'"'"''"'"'3aaR'

# Bootstrap and cleanup
echo "===== Performing Bootstrap and cleanup"
bundle exec bin/pg_easy_replicate bootstrap -g cluster-1 --copy-schema
bundle exec bin/pg_easy_replicate start_sync -g cluster-1 -s public
bundle exec bin/pg_easy_replicate stats -g cluster-1
bundle exec bin/pg_easy_replicate switchover -g cluster-1
