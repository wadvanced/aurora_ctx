# improve-issue · Core sections

Read by `improve-issue` **Draft** when a Core section is in scope. A Core section changes the
runtime the generated functions delegate to: `lib/aurora/ctx/core.ex` (`Aurora.Ctx.Core`),
`lib/aurora/ctx/query_builder.ex` (`Aurora.Ctx.QueryBuilder`) and `lib/aurora/ctx/pagination.ex`
(`Aurora.Ctx.Pagination`). A change confined to `lib/aurora/ctx.ex` — what gets generated, under
which name and arity — has no Core section.

## Rules

1. One Core section per capability. A capability that touches two Core modules (a new query
   option consumed by `Core.list/3`) stays one section when neither half works alone; two
   independent capabilities are two sections (`COR-1`, `COR-2`, sideways-independent).
2. Subsection order is fixed, and is the TDD order: acceptance criteria → test ports → red
   tests → Core changes → green tests.
3. Every test port carries its in and out shapes, and is marked `existing` (with its citation)
   or `new` (with its search evidence).
4. Clause order is stated. For each multi-clause function touched (`QueryBuilder.option/2`,
   `where_condition/2`, `or_where_condition/2`), name the clause the new one goes before. These
   functions end in a catch-all that **silently ignores** an unmatched input, so a clause placed
   after it never runs: the section states the position, and states any change to the catch-all
   itself as a behaviour change with its own AC.
5. `where` and `or_where` are parallel clause families. A comparator added to one is added to the
   other in the same section, or `### Out of Scope` states why only one applies.
6. Every public function added or whose contract changes carries its `@doc` (Parameters /
   Returns / Raises, per `.github/prompts/module_documentation.prompt.md`) and `@spec` in this
   section — `.doctor.exs` demands 100% of both — and a doctest when the function is pure. A new
   module with doctests is registered in `test/doc_test.exs`; name that edit.
7. Core takes the repo and the schema module from its caller — as arguments, or inside the
   `%Pagination{}` a paginated list built. A Core section never reads the
   application environment for a repo and never references a context module; resolving either
   belongs to the Macro section.
8. Test fixtures the section needs — a field on `test/support/inventory/*.ex`, a migration in
   `priv/repo/migrations/`, a helper in `test/support/helper.ex` — are prescribed here, by exact
   name, in the first Core section that needs them. `Aurora.Ctx.Repo` and these schemas are
   test-only and never shipped.
9. At least three ACs, at least one of them an error or edge path (an unknown option, a `nil`
   query, an empty list, a bang function raising).
10. Tests use `Aurora.Ctx.Test.RepoCase` and call the Core function directly with
    `Aurora.Ctx.Repo` and `Aurora.Ctx.Test.Support.Inventory.*` — no `Process.sleep/1`, no mocks.

## Template

```markdown
<!-- section:COR-k:start -->
### COR-k — Core · <capability>
Depends on: <DOC-1 for the first Core section; otherwise the sibling ids it follows>

#### Documentation references
<the guides § sections specifying this behaviour>

#### Implementation details
##### Acceptance criteria
- [ ] AC-1: Given <records or query>, when `Aurora.Ctx.<Module>.<function>/<arity>` is called
      with `<options>`, then <the observable result>

##### Test ports
- `Aurora.Ctx.<Core|QueryBuilder|Pagination>.<function>/<arity>` ·
  in: <shape> · out: <shape> · existing (`file.ex`, `fun/arity`) | new

##### Red tests (write first; each must fail before implementation)
| AC | Placement | Setup | Test file | Test name | Assertion sketch |
|---|---|---|---|---|---|
| AC-1 | amend \| add to \| new file | `create_sample_products(<n>)` | test/cases/core_test.exs | "<name>" | `assert <expression> == <value>` |

##### Core changes
1. `lib/aurora/ctx/<file>.ex` `<function>/<arity>` — new clause `<exact head>` placed before
   `<clause>`; catch-all: unchanged | changed to <behaviour>
2. `@doc` / `@spec`: <the lines added or changed>
3. Fixtures: <`test/support/…` or `priv/repo/migrations/…`, new | modified | none>

##### Green tests
1. The red tests above pass, unmodified (code-issue runs these, targeted)
2. `mix test` — full suite green (review-issue runs this; code-issue runs
   only this section's test files)
3. `mix compile --warnings-as-errors` clean
<!-- section:COR-k:end -->
```
