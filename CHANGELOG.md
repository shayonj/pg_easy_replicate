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
