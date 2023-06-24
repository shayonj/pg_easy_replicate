export SECONDARY_SOURCE_DB_URL="postgres://jamesbond:jamesbond123%407%21%273aaR@source_db/postgres"
export SOURCE_DB_URL="postgres://jamesbond:jamesbond123%407%21%273aaR@localhost:5432/postgres"
export TARGET_DB_URL="postgres://jamesbond:jamesbond123%407%21%273aaR@localhost:5433/postgres"

bundle exec bin/pg_easy_replicate config_check

# Bootstrap and cleanup
echo "===== Performing Bootstrap and cleanup"
bundle exec bin/pg_easy_replicate bootstrap -g cluster-1
bundle exec bin/pg_easy_replicate cleanup -e -g cluster-1

# Bootstrap and start_sync
echo "===== Performing Bootstrap, start_sync, stop_sync and cleanup"
bundle exec bin/pg_easy_replicate bootstrap -g cluster-1
bundle exec bin/pg_easy_replicate start_sync -g cluster-1
bundle exec bin/pg_easy_replicate stop_sync -g cluster-1
bundle exec bin/pg_easy_replicate cleanup -e -g cluster-1

# Bootstrap with switchover
echo "===== Performing Bootstrap, start_sync, stop_sync and cleanup"
bundle exec bin/pg_easy_replicate bootstrap -g cluster-1
bundle exec bin/pg_easy_replicate start_sync -g cluster-1
# bundle exec bin/pg_easy_replicate switchover -g cluster-1
bundle exec bin/pg_easy_replicate cleanup -e -g cluster-1
