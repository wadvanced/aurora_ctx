# AGENTS.md

Canonical guidance for any AI coding agent working in this repository (Claude Code, GitHub Copilot, opencode, qwen-code, Cursor, Aider, etc.). `CLAUDE.md` includes this file via `@AGENTS.md`.

## Overview

`aurora_ctx` is an Elixir **macro library**, not an application: "a macro set for exposing schema access functions in context modules". A host context module declares

```elixir
defmodule MyApp.Inventory do
  use Aurora.Ctx

  ctx_register_schema(MyApp.Inventory.Product)
end
```

and gets `list_products/0,1`, `get_product/1,2`, `create_product/0,1`, `update_product/1,2`, `change_product/1,2`, pagination helpers and the rest, generated at compile time from the Ecto schema. `guides/functions.md` is the reference for every generated function; `guides/overview.md` and `guides/examples.md` cover usage.

It is published to Hex. The package ships only `lib/` (minus the test-only repo), `mix.exs`, `README.md`, `CHANGELOG.md` and `.formatter.exs`.

## Commands

```bash
# Setup
mix deps.get

# Testing  (the `test` alias runs `ctx.test.setup` first: ecto.create + ecto.migrate)
mix test                                 # full suite
mix test test/cases/core_test.exs        # one file
mix test test/cases/core_test.exs:42     # one test

# Quality gate (run before committing) — see "Quality Gate" below
mix consistency              # format, compile, credo, dialyzer, doctor
mix format                   # Auto-format code
mix credo --strict           # Lint
mix dialyzer                 # Static analysis (first run is slow)
mix doctor                   # Documentation and spec coverage

# Per-checkout test database (skipped on CI)
scripts/test_pg.sh status    # private PostgreSQL for this checkout; `ensure` starts it, `sweep` retires stale ones
scripts/test_pg.sh psql      # psql on this checkout's test instance
AURORA_CTX_TEST_PG=shared mix test   # opt out: use the localhost aurora_ctx_repo database

# Docs
mix docs                     # ExDoc, from guides/ and the module docs
```

`mix consistency` runs in the default `:dev` environment — `dialyxir`, `doctor` and `ex_doc` are dev-only dependencies.

## Naming Conventions

- Modules live under `Aurora.Ctx` (`lib/aurora/ctx/*.ex`); Mix tasks under `Mix.Tasks.Ctx.` (`lib/mix/`).
- Generated function names follow the patterns in `guides/functions.md`: singular functions use the **infix** (default: the schema module's last segment, underscored — `get_product`), plural ones the **plural infix** (default: the schema's table name — `list_products`). Both are overridable per `ctx_register_schema` call.
- Files named `-local-*.*` are gitignored personal scratch files, excluded from the package, the docs and `doctor`.

## Glossary

| Term | Meaning |
|---|---|
| **context module** / **host** | the application module that `use`s `Aurora.Ctx` |
| **Macro layer** | `lib/aurora/ctx.ex` — `__using__/1`, `ctx_register_schema`, `implementable_functions/2`, `generate_function/1`, `__before_compile__/1` |
| **Core layer** | `Aurora.Ctx.Core`, `Aurora.Ctx.QueryBuilder`, `Aurora.Ctx.Pagination` — the runtime the generated functions delegate to |
| **generated function** | a function the Macro layer defines in the host, e.g. `list_products/1` |
| **infix** / **plural infix** | the variable part of a generated function's name |
| **query options** | the keyword list accepted by list/get/count functions: `:where`, `:or_where`, `:order_by`, `:preload`, `:paginate`, `:select` |

## Architecture

### Core Structure

```
lib/aurora/ctx.ex                Macro layer: what is generated, under which name and arity
lib/aurora/ctx/core.ex           Core layer: list, get, create, update, delete, change, count, pagination
lib/aurora/ctx/query_builder.ex  Query options -> Ecto.Query (where / or_where / order_by / preload / paginate / select)
lib/aurora/ctx/pagination.ex     The pagination struct and its defaults
lib/aurora/ctx/repo.ex           TEST-ONLY Ecto repo (excluded from the Hex package)
lib/mix/ctx.test.setup.ex        TEST-ONLY task: creates and migrates the test database
priv/repo/migrations/            TEST-ONLY migrations for the schemas in test/support/inventory/
guides/                          overview.md, functions.md, examples.md (published with ExDoc)
test/cases/                      the suite; test/support/ holds RepoCase, helpers and the test schemas
```

### Key Patterns

**Macro / Core boundary (STRICT).** The Macro layer decides *what* is generated; the Core layer decides *how* it behaves.

- A `generate_function/1` clause binds its arguments and delegates to `Aurora.Ctx.Core`. Generated code carries no query, no `Repo` call and no runtime branching. Branching at compile time on the entry (`type`, `arity`) is how a clause picks its shape.
- `Aurora.Ctx.Core`, `QueryBuilder` and `Pagination` receive the repo module and the schema module from their caller — as arguments, or inside the `%Pagination{}` a paginated list call built. They never resolve a repo, never read a context module, and never reference `Aurora.Ctx.Repo`.

```elixir
# ❌ Bad — behaviour inside the generated function
quote do
  def unquote(function.name)(opts) do
    unquote(function.schema_module) |> where(^opts[:where]) |> unquote(function.repo_module).all()
  end
end

# ✅ Good — the generated function only delegates
quote do
  def unquote(function.name)(opts) do
    Ctx.Core.list(unquote(function.repo_module), unquote(function.schema_module), opts)
  end
end
```

**Two hand-kept lists (STRICT).** `implementable_functions/2` lists every generated function (`type`, name, arity); `generate_function/1` has one clause per `type`. An entry whose `type` no clause matches falls to the final `generate_function(_func)` clause and generates **nothing, silently**. Add the entry and the clause together, and document the name in `guides/functions.md`.

**Silent catch-alls.** `QueryBuilder.option/2`, `where_condition/2`, `or_where_condition/2` and `generate_function/1` each end in a clause that ignores unrecognised input. New clauses go **before** the catch-all. Changing what a catch-all does is a behaviour change to specify and test, never a side effect.

**`where` / `or_where` parity.** The two clause families in `query_builder.ex` mirror each other. A comparator added to one is added to the other.

**Host override.** A function the host defines with the same name and arity replaces the generated one (`test/cases/function_override_test.exs`).

**Changesets belong to the host schema.** The library calls the configured function (`:changeset`, `:create_changeset`, `:update_changeset` options); it never casts or validates.

**Repo resolution.** In order: the repo passed to `ctx_register_schema/3`, the host's `@ctx_repo_module`, then `<HostApp>.Repo` derived from the context module's namespace. Resolved at compile time in the Macro layer.

**Test-only code stays test-only.** `Aurora.Ctx.Repo`, `Mix.Tasks.Ctx.Test.Setup`, `test/support/**` and `priv/repo/migrations/**` exist for the suite. Library code never references them.

### Tech Stack

- Elixir `~> 1.17` (CI: Elixir 1.18.4 / OTP 28.0.1, see `.tool-versions`)
- Runtime deps: `ecto_sql`, `postgrex`
- Dev/test: `credo`, `dialyxir`, `doctor`, `ex_doc`
- No Phoenix, no supervision tree, no runtime configuration beyond the optional `config :aurora_ctx, :paginate` / `:pagination` compile-time defaults

## Elixir Language Gotchas

Project-specific syntax/behavior rules that are easy to get wrong:

- Lists do **not** support index access (`mylist[i]` is invalid). Use `Enum.at/2`, pattern matching, or `List` functions.
- Block expressions (`if`, `case`, `cond`) must have their result rebound: `query = if ... do ... end`
- **Never** nest multiple modules in the same file under `lib/` (cyclic dependency risk). Test files declare one nested context module each — that is the convention there
- **Never** use map access syntax (`changeset[:field]`) on structs — use `struct.field` or `Ecto.Changeset.get_field/2`
- Predicate functions end with `?`, not `is_` prefix (reserve `is_` for guards)
- Use `Task.async_stream/3` with `timeout: :infinity` for concurrent enumeration

## Elixir Anti-Patterns to Avoid

Authoritative rules derived from the [official Elixir anti-patterns guide](https://hexdocs.pm/elixir/what-anti-patterns.html). **Follow each rule literally.** If you find yourself writing one of the ❌ patterns, stop and rewrite as the ✅ version.

### Code Anti-Patterns

#### 1. Do not overuse comments
Comments must explain *why*, never *what*. If a comment restates the code, delete it.
```elixir
# ❌ Bad
# Increment counter by 1
counter = counter + 1

# ✅ Good — only when the why is non-obvious
# Backoff doubles each retry to avoid thundering herd
delay = delay * 2
```

#### 2. Do not write complex `else` clauses in `with`
Each `with` step's error must be distinguishable. Do not pile every error type into one `else`.
```elixir
# ❌ Bad
with {:ok, user} <- fetch_user(id),
     {:ok, post} <- fetch_post(user) do
  {:ok, post}
else
  nil -> {:error, :not_found}
  {:error, _} -> {:error, :failed}   # which step failed?
end

# ✅ Good — normalize returns inside helpers so `else` is unnecessary or trivial
with {:ok, user} <- fetch_user(id),
     {:ok, post} <- fetch_post(user) do
  {:ok, post}
end
```

#### 3. Do not extract complex values across many clauses
Pattern-match in the head only what is needed for dispatch. Bind extra fields inside the body.
```elixir
# ❌ Bad
def process(%{user: %{email: email, name: name}, meta: %{ip: ip, ua: ua}}), do: ...

# ✅ Good
def process(%{user: user, meta: meta}) do
  %{email: email, name: name} = user
  %{ip: ip, ua: ua} = meta
  ...
end
```

#### 4. Do not create atoms dynamically
`String.to_atom/1` on user/external input leaks memory. Atoms are never garbage-collected.
```elixir
# ❌ Bad — never on untrusted input
String.to_atom(params["role"])

# ✅ Good
String.to_existing_atom(params["role"])   # crashes if unknown — safe
# or explicit mapping:
case params["role"] do
  "admin" -> :admin
  "user"  -> :user
end
```

#### 5. Do not write long parameter lists
If a function takes more than ~4 arguments, group them into a struct, map, or keyword list.
```elixir
# ❌ Bad
def register(schema, repo, infix, plural_infix, changeset, create_changeset, update_changeset), do: ...

# ✅ Good
def register(schema, repo, opts) when is_list(opts), do: ...
```

#### 6. Do not trespass namespaces
Every module this project defines must start with `Aurora.Ctx` (or `Mix.Tasks.Ctx.`). Never define modules under `Ecto.`, `Enum.`, etc. Generated functions land in the **host's** context module — keep their names to the documented patterns so they never collide with the host's own.

#### 7. Do not use non-assertive map access
For keys that **must** be present, use `map.key` (crashes on missing). Use `map[:key]` only for truly optional keys.
```elixir
# ❌ Bad — silently returns nil if :name is missing
user[:name]

# ✅ Good
user.name                   # required field
Map.get(user, :nickname)    # truly optional field
```

#### 8. Do not write non-assertive pattern matches
Match the exact shape you expect. Do not use overly permissive patterns to "be safe".
```elixir
# ❌ Bad — accepts anything, hides bugs
def get_id(value), do: value["id"]

# ✅ Good — crashes loudly if shape is wrong
def get_id(%{"id" => id}), do: id
```

#### 9. Do not use truthy operators on booleans
Use `and`, `or`, `not` when both sides are guaranteed booleans. Reserve `&&`, `||`, `!` for nil/falsy logic.
```elixir
# ❌ Bad
if active? && verified?, do: ...

# ✅ Good
if active? and verified?, do: ...
```

#### 10. Do not create structs with 32 or more fields
Past 32 fields, the struct switches representation and loses optimizations. Split into nested structs.

### Design Anti-Patterns

#### 11. Do not return alternative types from one function
A function's return type must not change based on options. Split into separate functions.
```elixir
# ❌ Bad
def find_user(id, opts \\ []) do
  if opts[:raise], do: %User{...}, else: {:ok, %User{...}}
end

# ✅ Good
def find_user(id), do: {:ok, ...}
def find_user!(id), do: ...   # raises
```

#### 12. Do not encode state with multiple booleans
Use a single atom-valued field instead of overlapping boolean flags.
```elixir
# ❌ Bad
%Field{is_association: true, is_embed: false, is_upload: false}

# ✅ Good
%Field{type: :one_to_many_association}
```

#### 13. Do not use exceptions for control flow
Expected failures (validation, not-found, etc.) return `{:ok, _}` / `{:error, _}`. Reserve `raise`/`rescue` for truly unexpected conditions.
```elixir
# ❌ Bad
def get_user(id) do
  try do
    Repo.get!(User, id)
  rescue
    Ecto.NoResultsError -> nil
  end
end

# ✅ Good
def get_user(id) do
  case Repo.get(User, id) do
    nil  -> {:error, :not_found}
    user -> {:ok, user}
  end
end
```

#### 14. Do not use primitive types for domain concepts
Wrap domain values in structs/maps, not bare strings/integers/tuples.
```elixir
# ❌ Bad
def to_page({1, 40, 120}, page), do: ...

# ✅ Good
def to_page(%Pagination{} = pagination, page), do: ...
```

#### 15. Do not group unrelated logic in one multi-clause function
Multiple clauses of the same function must implement the *same* operation on different shapes. If clauses do unrelated things, split into named functions.

#### 16. Do not use Application config for library/module behavior
Pass configuration through function arguments or struct fields, not via `Application.get_env/2` reads at call time. Reading global config inside a function makes it untestable and non-reentrant.

### Process Anti-Patterns

#### 17. Do not use processes for code organization
Processes (`GenServer`, `Agent`, `Task`) exist to model **concurrency, state isolation, or fault isolation**. They are not a way to "group" code. Use modules and functions for that.

#### 18. Do not scatter process interfaces
All calls to a given `GenServer`/`Agent` go through one wrapper module that owns its API. Do not call `GenServer.call/2` directly from arbitrary callers.

#### 19. Do not send unnecessary data to processes
When sending messages or spawning, capture only the fields you need — not whole structs.
```elixir
# ❌ Bad
Task.async(fn -> process(pagination) end)

# ✅ Good
entries_count = pagination.entries_count
Task.async(fn -> process(entries_count) end)
```

#### 20. Do not start unsupervised processes
Every long-lived process must be added to the supervision tree in `application.ex` (or under a `DynamicSupervisor`). Never call `GenServer.start_link/3` from arbitrary code paths without supervision.

### Meta-Programming Anti-Patterns

#### 21. Do not introduce unnecessary compile-time dependencies in macros
A macro that references another module via `Macro.expand/2` of an alias creates a compile-time dep and forces recompiles. Prefer runtime references where possible.

#### 22. Do not generate large amounts of code in macros
If a macro emits dozens of lines per invocation, move the logic into a helper function called from the `quote` block.

#### 23. Do not write unnecessary macros
Use functions unless you specifically need to manipulate AST or inject code at compile time. If a function would work, use a function.

#### 24. Do not use `use` when `import` or `alias` suffices
`use SomeModule` triggers `__using__/1` and injects unknown code. Prefer `alias` (for naming) or `import` (for direct calls). Reserve `use` for libraries that explicitly require it (Ecto, ExUnit, etc.).

#### 25. Do not create module names dynamically
Building module names via `String.to_atom/1` or `Module.concat/1` from runtime data hides dependencies from the compiler.
```elixir
# ❌ Bad
mod = String.to_atom("Elixir.Aurora.Ctx.#{name}")
mod.run(query)

# ✅ Good — explicit dispatch
case name do
  "query_builder" -> QueryBuilder.options(query, opts)
  "pagination" -> Pagination.new(opts)
end
```

## Documentation

- `.github/prompts/module_documentation.prompt.md` is the project's documentation spec (named by `CONTRIBUTING.md`); the `documentation` skill in `.claude/skills/` applies it.
- `doctor` (`.doctor.exs`) demands **100%** `@moduledoc`, `@doc` and `@spec` coverage. `@doc` and `@spec` go on the **first clause only** of each arity group; private functions carry `@spec` and sit below a single `## PRIVATE` comment.
- Generated functions are emitted with `@doc false`; they are documented by name pattern in `guides/functions.md` and in the `@moduledoc` of `Aurora.Ctx`.
- Every feature and fix gets a `CHANGELOG.md` entry under `## [Unreleased]` (`### Added`, `### Changed`, `### Fixed`), with no issue link. Released sections (`## v<version>`) are never edited.
- Cite guides by section name (`guides/functions.md § List Functions`), never by line number.

## Testing

### Test layers

| File | Covers |
|---|---|
| `test/cases/core_test.exs` | `Aurora.Ctx.Core` called directly |
| `test/cases/single_schema_test.exs`, `infix_schema_test.exs` | the generated surface and its naming options |
| `test/cases/option_*_test.exs` | the changeset options of `ctx_register_schema` |
| `test/cases/function_override_test.exs` | a host function replacing a generated one |
| `test/doc_test.exs` | doctests of `Aurora.Ctx`, `Core`, `Pagination`, `QueryBuilder` |

### Test Case Modules

- `use Aurora.Ctx.Test.RepoCase` — it starts the SQL sandbox and imports `Aurora.Ctx.Test.Support.Helper`. There is no factory.
- Test data comes from `test/support/helper.ex` (`create_sample_products/1`, `delete_all_products/0`) and the schemas in `test/support/inventory/`.
- A Macro-layer test declares its own context module **inside the test file** (`use Aurora.Ctx`, `@ctx_repo_module Aurora.Ctx.Repo`, `ctx_register_schema(Product, …)`) and asserts through the functions it generated.
- **Each checkout has its own test PostgreSQL instance** (`scripts/test_pg.sh`, wired in `test/config/test.exs`), reached over a Unix socket under `/tmp/aurora_ctx_pg/`, so the main clone and every git worktree can run `mix test` at the same time. On CI (`CI` set), or with `AURORA_CTX_TEST_PG=shared`, the plain `localhost` database `aurora_ctx_repo` is used.
- **The `test` alias creates and migrates the database** (`ctx.test.setup`) before every run; there is no separate migrate step. `config/` is gitignored: an optional local `config/test.exs` overrides `test/config/test.exs`.

### Scope and Coverage

- **Write concise, targeted tests.** Each test should assert one behavior clearly.
- **Don't over-test.** Once a behavior is covered, do not repeat the same assertion in another test file.
- Test names describe observable behavior — never an issue number or an acceptance-criterion id.
- A comparator added to `where` is tested through `or_where` too.

### No Mocks

- **Never use mocks.** Test against the real repo with real database state.
- Assert on returned values and their shapes. Never assert on `inspect/1` output, on the internals of an `%Ecto.Query{}`, or on quoted AST — run the query, call the function.
- Never use `Process.sleep/1`.

## Quality Gate

Run `mix consistency` then `mix test` before pushing. The `consistency` alias is fail-fast and executes, in order:

```
format → compile --warnings-as-errors → credo --strict → dialyzer → doctor
```

Only the **first failing stage** is visible per run — fix it, re-run, repeat. `mix consistency` does **not** run tests; CI runs `mix test` as a separate step. Note that the `format` stage *rewrites* files rather than checking them.

`doctor` enforces documentation coverage, which in this codebase means:
- `@moduledoc` on every module
- `@doc` + `@spec` on public functions — on the **first clause only**
- `@spec` on private functions too

Dialyzer also analyses the functions the macros generate, through the context modules compiled in the project. Never weaken or invent a `@spec` to silence it.

Fix all issues before committing. Commits follow Conventional Commits (`CONTRIBUTING.md`): `type(scope): subject`, imperative, lowercase, no trailing period.

## Workflow

The issue → PR pipeline lives in `.claude/skills/` (see `.claude/skills/README.md`): `improve-issue` → `code-issue` → `review-issue` → `pr-from-issue` → `merge-pr`, driven end to end by `orchestrate-issue` and the `epic-orchestrator` agent. An issue is partitioned into sections — `DOC-1` (documentation) → `COR-k` (Core layer) → `MAC-k` (Macro layer) — one branch and one PR each. Specs are stored as `specs/issue-<n>-enriched-spec.md` through a spec PR; **never commit to `main` directly** (the ruleset requires a PR and the `Build and test (1.18.4, 28.0.1)` check). Long gates run through `.claude/scripts/gate.sh` / `suite.sh` (a hook rejects direct `mix consistency` runs, backgrounded gates and poll loops). `approved` and `amends-required` are human-only PR labels: never add or remove them.

Dependency bumps go through the `bump-dependencies` skill, which also closes the `bump` issues `.github/workflows/dependency-check.yml` opens.

When working on issues, always read the full issue description and linked issues before starting implementation.
If an issue involves multiple steps (docs, refactor, PR), outline the plan first and confirm before proceeding.
