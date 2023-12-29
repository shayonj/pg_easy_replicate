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
