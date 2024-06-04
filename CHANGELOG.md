## [0.2.6] - 2024-06-04

- Quote table name in the VACUUM SQL - #118
- Exclude tables created by extensions - #120
- Use db user when adding tables to replication - #130

## [0.2.5] - 2024-04-14

- List only permanent tables - #113

## [0.2.4] - 2024-02-13

- Introduce PG_EASY_REPLICATE_STATEMENT_TIMEOUT env var

## [0.2.3] - 2024-01-21

- Fix tables check in config_check - #93
- add option to skip vacuum analyzing on switchover - #92
- Disable statement timeout and reset it before/after vacuum+analyze - #94
- Add spec for skip_vacuum_analyze - #95

Highlights

- You can now skip vacuum and analyze by passing `--skip-vacuum-analyze` to `switchover`. Thanks to @honzasterba
- Vacuum and Analyze won't run into timeouts. Thanks to the report from @TrueCarry

## [0.2.2] - 2024-01-21

- Extend config check to assert for REPLICA IDENTITY on tables and drop index bug - #88

## [0.2.1] - 2024-01-20

- Don't attempt to drop and recreate unique indices - #88
- Dependency updates

## [0.2.0] - 2023-12-29

- Recreate indices post COPY, once all tables are in replicating mode - #81

## [0.1.12] - 2023-12-13

- Bump rubocop-rspec from 2.24.1 to 2.25.0 - #65
- Quote indent DB name - #76

## [0.1.12] - 2023-12-13

- Drop existing user with privileges when bootstrapping - #75

## [0.1.10] - 2023-12-12

- Reference the passed in URL and use source db url - #74

## [0.1.9] - 2023-08-01

- Exclude views, temporary tables and foreign tables from #list_all_tables - #39
- Add quote_identifier helper for SQL identifiers. - #40
- Escape db user name in queries - #42
- Require english lib so that $CHILD_STATUS is loaded - #43
- Bump rubocop from 1.54.2 to 1.55.0 - #37
- Bump rubocop-rspec from 2.22.0 to 2.23.0 - #36
- Quote indent username, dbname and schema in all places - #44

## [0.1.8] - 2023-07-23

- Introduce --copy_schema via pg_dump - #35

## [0.1.7] - 2023-06-26

- Perform smoke test with retries in CI - #26
- Default schema to `public` #29
- Perform vacuum and analyze before and after switchover - #30

## [0.1.6] - 2023-06-24

- Bug fix: Support custom schema name
- New smoke spec in CI

## [0.1.5] - 2023-06-24

- Fix bug in `stop_sync`

## [0.1.4] - 2023-06-24

- Drop lockbox dependency
- Support password with special chars and test for url encoded URI
- Support AWS and GCP special user scenarios and introduce `--special-user-role`

## [0.1.3] - 2023-06-22

- Docker multi-platform image build support for linux/amd64 and linux/arm64 starting 0.1.3

## [0.1.2] - 2023-06-22

- Keep the internal username unique

## [0.1.1] - 2023-06-21

- Don't leak bin/console and bin/setup into `$PATH`
- Typo fixes

## [0.1.0] - 2023-06-19

- Initial release
