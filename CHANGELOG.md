# Changelog for v0.x

## v0.1.4
Uses Elixir v1.18+
Compatible with Ecto 3.12+

### Documentation update and fixes

### Features
- Add get_by function generation.
- Custom changeset functions can be defined by name or by function reference.

### Dependencies upgrade
- `db_connection` - upgraded and locked from: 2.7.0 to 2.8.0
- `ecto` - upgraded and locked from: 3.12.5 to 3.13.2
- `ecto_sql` - upgraded and locked from: 3.12.1 to 3.13.2

## v0.1.3
Requires Elixir v1.17+
Compatible with Ecto 3.12+

### Documentation update and fixes
- README.md - logo added.
- Hex docs - logo added.
- Functions.md - improved to reflect new functionalities.
- Examples.md - Phoenix Liveview example added.
- Modules - Modules documentation updated.
- Identity assets - logo and icons added.

### Dependencies upgrade
- `ex_doc` - upgraded and locked from: 0.38.1 to 0.38.2

## v0.1.2
Requires Elixir v1.17+
Compatible with Ecto 3.12+

### Documentation update and fixes
- README.md - more details added.
- overview.md - description of pagination functions added.
- functions.md - description of pagination functions.
- examples.md - Added Phoenix examples of pagination functions, improved multiple changeset examples.

### Features
- Added a `:changeset` option to ctx_register_schema. 
  This provides a default changeset for create, update and change functions.

## v0.1.1
Requires Elixir v1.17+
Compatible with Ecto 3.2+

### Fixes
- Mix task test.setup renamed to ctx.test.setup, to avoid conflicts with other apps or libraries.

### Features
- Two new options added to ctx_register_schema
    - :infix and :plural_infix to change the names that are generated.
- Implemented create_changeset and update_changeset.
- Navigation functions added:
    - to_(plural_inflix)_page/2, next_(plural_inflix)_page/1, previous_(plural_inflix)_page/1 

### Upgraded dependencies
- `ex_doc` - upgraded and locked from 0.37.2 to 0.38.1

## v0.1.0

Requires Elixir v1.17+
Compatible with Ecto 3.2+

### Features

- Automatic CRUD function generation for Ecto schemas
- Customizable repository module selection
- Customizable changeset function names
- Support for both safe and raising versions of operations
- Built-in support for preloading associations
