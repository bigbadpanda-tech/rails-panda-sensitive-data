# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.0.0] - 2025-11-26

### Added
- Comprehensive RSpec test suite
- SimpleCov integration for test coverage tracking
- `nil_visible_in_db` option to control whether nil values are visible in the database or encrypted
- `whitespace_visible_in_db` option to control whether whitespace-only strings are visible in the database or encrypted
- `rails_default` option to `encrypts` to bypass custom logic and use Rails' standard behavior
- Full dirty tracking support for `has_sensitive_data` attributes:
  - `#{field}_changed?` - Check if field has changed but not saved
  - `#{field}_in_database` - Get value currently in database
  - `#{field}_before_last_save` - Get value before last save
  - `saved_change_to_#{field}?` - Check if field changed in last save
  - `saved_change_to_#{field}` - Get `[before, after]` array of last save change
  - `will_save_change_to_#{field}?` - Check if field will change on next save
  - `#{field}_change_to_be_saved` - Get `[current_db_value, new_value]` array of pending changes
- Auto-inclusion of module in all ActiveRecord::Base models via `ActiveSupport.on_load`
- ArgumentError raised when `encrypts` or `has_sensitive_data` are called without attributes

### Changed
- Module is now automatically included in all ActiveRecord::Base models (no manual inclusion needed)
- Removed custom `KeyProvider` and `Key` classes - now uses Rails' default key management
- Renamed `store_nil_as_empty_string` to `nil_visible_in_db` for clarity
- `empty_string_visible_in_db` now defaults to `true` (was `false` in previous versions)
- `nil_visible_in_db` now defaults to `true` (nil values stored as nil, not encrypted)
- Improved code safety and type checking in Encryptor
- All dirty tracking methods match Rails' standard behavior exactly
- Improved `attribute_before_last_save` implementation to use Rails' built-in `attribute_before_last_save` method instead of manual method calls
- Improved `saved_change_to_attribute?` to correctly handle `nil` values (returns `false` when `before_last_save` is `nil` after reload, matching Rails' behavior)

### Fixed
- Fixed Encryptor to properly pass options to parent class methods
- Fixed type checking for empty string handling in Encryptor

## [2.0.6] - 2025-10-06

### Changed
- Fixed loading issues - gem now loads correctly
- Added frozen string literal comments to all files

### Fixed
- Fixed module loading and initialization issues

## [2.0.5] - 2025-10-05

### Changed
- Removed a useless module

## [2.0.4] - 2023-10-10

### Changed
- Various improvements and bug fixes

## [2.0.2] - 2023-10-08

### Changed
- Various improvements and bug fixes

## [2.0.1] - 2023-10-06

### Changed
- Various improvements and bug fixes

## [2.0.0] - 2023-03-18

### Changed
- Removed `attr_encrypted` dependency
- Migrated to use ActiveRecord::Encryption (Rails 7.0+)
- Major refactoring to use Rails' built-in encryption framework

## [1.0.2] - 2023-03-11

### Changed
- Various improvements and bug fixes

## [1.0.1] - 2022-03-23

### Changed
- Various improvements and bug fixes

## [1.0.0] - 2018-02-20

### Added
- Initial release
- Module to handle encryption for GDPR compliance
- Support for encrypting sensitive data in ActiveRecord models
- Support for storing multiple sensitive fields in a single encrypted attribute

[Unreleased]: https://github.com/bigbadpanda-tech/rails-panda-sensitive-data/compare/v3.0.0...HEAD
[3.0.0]: https://github.com/bigbadpanda-tech/rails-panda-sensitive-data/compare/v2.0.6...v3.0.0
[2.0.6]: https://github.com/bigbadpanda-tech/rails-panda-sensitive-data/compare/v2.0.5...v2.0.6
[2.0.5]: https://github.com/bigbadpanda-tech/rails-panda-sensitive-data/compare/v2.0.4...v2.0.5
[2.0.4]: https://github.com/bigbadpanda-tech/rails-panda-sensitive-data/compare/v2.0.2...v2.0.4
[2.0.2]: https://github.com/bigbadpanda-tech/rails-panda-sensitive-data/compare/v2.0.1...v2.0.2
[2.0.1]: https://github.com/bigbadpanda-tech/rails-panda-sensitive-data/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/bigbadpanda-tech/rails-panda-sensitive-data/compare/v1.0.2...v2.0.0
[1.0.2]: https://github.com/bigbadpanda-tech/rails-panda-sensitive-data/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/bigbadpanda-tech/rails-panda-sensitive-data/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/bigbadpanda-tech/rails-panda-sensitive-data/releases/tag/v1.0.0
