# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## v0.1.8

### Changed
- `credo` upgraded from 1.7.12 to 1.7.13
- `dialyxir` upgraded from 1.4.6 to 1.4.7 
- `ex_doc` upgraded from 0.38.4 to 0.39.1 
 
## v0.1.7
- Uses Elixir v1.18+
- Compatible with Ecto 3.12+

### Fixed
- Dialyzir failure on generated change and update functions.

### Changed
- `ex_doc` upgraded from 0.38.2 to 0.38.4
- `dialyxir` upgraded from 1.4.5 to 1.4.6
- `postgrex` upgraded from 0.20.0 to 0.21.1
- documentation
- adoption of [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
- adoption of [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)

## v0.1.6
- Uses Elixir v1.18+
- Compatible with Ecto 3.12+

### Fixed
- Pagination fails when relying on the default per_page value.

## v0.1.5
- Uses Elixir v1.18+
- Compatible with Ecto 3.12+

### Added
- Where condition options
  - :like and :ilike conditions in where options
  - Dynamic queries - Ecto.Query.DynamicExpr allowed in where options.
- Select option (:select)
  - List of fields to load from table specified as option.  

### Changed
- Guides documentation updated
- New CONTRIBUTORS.md documentation

## v0.1.4
- Uses Elixir v1.18+
- Compatible with Ecto 3.12+

### Added
- Add get_by function generation.
- Custom changeset functions can be defined by name or by function reference.

### Changed
- `db_connection` - upgraded and locked from: 2.7.0 to 2.8.0
- `ecto` - upgraded and locked from: 3.12.5 to 3.13.2
- `ecto_sql` - upgraded and locked from: 3.12.1 to 3.13.2

## v0.1.3
- Requires Elixir v1.17+
- Compatible with Ecto 3.12+

### Changed
- README.md - logo added.
- Hex docs - logo added.
- Functions.md - improved to reflect new functionalities.
- Examples.md - Phoenix Liveview example added.
- Modules - Modules documentation updated.
- Identity assets - logo and icons added.
- `ex_doc` - upgraded from 0.38.1 to 0.38.2

## v0.1.2
- Requires Elixir v1.17+
- Compatible with Ecto 3.12+

### Added
- Added a `:changeset` option to ctx_register_schema. 
  This provides a default changeset for create, update and change functions.

### Changed
- README.md - more details added.
- overview.md - description of pagination functions added.
- functions.md - description of pagination functions.
- examples.md - Added Phoenix examples of pagination functions, improved multiple changeset examples.

## v0.1.1
- Requires Elixir v1.17+
- Compatible with Ecto 3.2+

### Fixed
- Mix task test.setup renamed to ctx.test.setup, to avoid conflicts with other apps or libraries.

### Added
- Two new options added to ctx_register_schema
    - :infix and :plural_infix to change the names that are generated.
- Implemented create_changeset and update_changeset.
- Navigation functions added:
    - to_(plural_inflix)_page/2, next_(plural_inflix)_page/1, previous_(plural_inflix)_page/1 

### Changed
- `ex_doc` - upgraded and locked from 0.37.2 to 0.38.1

## v0.1.0
- Requires Elixir v1.17+
- Compatible with Ecto 3.2+

### Added
- Automatic CRUD function generation for Ecto schemas
- Customizable repository module selection
- Customizable changeset function names
- Support for both safe and raising versions of operations
- Built-in support for preloading associations
