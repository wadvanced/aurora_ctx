<!-- enriched-spec:start v2 -->
## Enriched Spec

**Complexity:** normal

### Overview
Adds the `:in` comparator to both `where` and `or_where` condition families of `Aurora.Ctx.QueryBuilder`, taking a list of values and a comma-separated binary. The two condition catch-alls raise `ArgumentError` naming the condition instead of dropping it. The issue ships as release 0.1.11: `DOC-1` carries the release CHANGELOG section and the install snippets, `COR-1` carries the Core layer change and the `mix.exs` version.

### Section Map
| ID | Type | Scope | Depends on | Branch | PR title |
|---|---|---|---|---|---|
| DOC-1 | Documentation | CHANGELOG.md § v0.1.11 · README.md § Installation · guides/functions.md § List Functions, § Where Conditions · guides/overview.md § Getting Started | none | federico/42-doc-1-in-comparator-release | docs: document the :in comparator and release 0.1.11 (#42 · DOC-1) |
| COR-1 | Core | `:in` comparator in `where_condition/2` and `or_where_condition/2`; raising catch-alls; version 0.1.11 | DOC-1 | federico/42-cor-1-in-comparator | feat: support :in and raise on unsupported where conditions (#42 · COR-1) |

A section starts only when every dependency is **merged**. Independent
sections may run in parallel. Status is derived from GitHub, never recorded
here.

<!-- section:DOC-1:start -->
### DOC-1 — Documentation
Depends on: none

#### Documentation references
- `CHANGELOG.md § [Unreleased]`, `§ v0.1.10` (the release-section style: `## v0.1.10` then `### Changed`, no Elixir / Ecto lines)
- `README.md § Installation`
- `guides/functions.md § List Functions`, `§ Query Options` › `§ Where Conditions`
- `guides/overview.md § Getting Started`

#### Implementation details

Release decision (recorded): this issue releases 0.1.11. The CHANGELOG entries therefore go under a new `## v0.1.11` section, not under `## [Unreleased]`.

##### CHANGELOG.md
1. § `## [Unreleased]` — keep the heading `## [Unreleased]`, followed by one blank line and no entries.
2. Insert, between the blank line after `## [Unreleased]` and the line `## v0.1.10`, verbatim:
   ```
   ## v0.1.11
   ### Added
   - `:in` comparator for `:where` and `:or_where` conditions: `{field, :in, values}` takes a list of values, or a comma-separated binary split on `","`

   ### Changed
   - A `:where` or `:or_where` condition that matches no supported form raises `ArgumentError` naming the condition, instead of being silently ignored

   ```
3. Every entry present under `## [Unreleased]` on `origin/main` when this section is coded moves into `## v0.1.11`, under the subsection of the same name (`### Added`, `### Changed`, `### Fixed`, created in that order when absent), after the entries of step 2.
4. `## v0.1.10` and every older section stay byte-identical.

##### README.md
1. § Installation — in the `deps` code block, replace `{:aurora_ctx, "~> 0.1.10"}` with `{:aurora_ctx, "~> 0.1.11"}`.

##### guides/functions.md
1. § List Functions — replace the line
   ```
   - `:where` - Filter conditions (equality, comparison, range)
   ```
   with
   ```
   - `:where` - Filter conditions (equality, comparison, membership, range)
   ```
2. § Query Options › § Where Conditions — in the code block, insert between the line `where: {:price, :between, 100, 200}` plus its following blank line and the line `# Dynamic queries`, verbatim:
   ```
   # Membership
   where: {:reference, :in, ["item_001", "item_045"]}
   where: {:reference, :in, "item_001,item_045"}   # comma-separated binary, split on ","

   ```
3. § Where Conditions — after the closing fence of that code block and before the heading `### Preloading`, insert verbatim, with one blank line before and after:
   ```
   `:or_where` accepts the same conditions as `:where`. A condition that matches none of the forms above raises `ArgumentError` (`unsupported where condition: ...`, `unsupported or_where condition: ...`) instead of being ignored.
   ```

##### guides/overview.md
1. § Getting Started — in the `deps` code block, replace `{:aurora_ctx, "~> 0.1.10"}` with `{:aurora_ctx, "~> 0.1.11"}`.

##### Acceptance criteria
- [ ] AC-1: the CHANGELOG entries sit under `## v0.1.11`, directly below an empty `## [Unreleased]`, and carry no issue-link suffix (mechanical — no red test; verified by
      `git diff origin/main...HEAD -- CHANGELOG.md | grep -E '^\+.*\[#[0-9]+\]'` returning nothing, and `grep -n -A2 '^## \[Unreleased\]' CHANGELOG.md` showing `## v0.1.11` two lines below)
- [ ] AC-2: no file outside the documentation set modified, apart from this issue's spec file
      (its AC ticks) (mechanical — no red test; verified by
      `git diff --name-only origin/main...HEAD` listing only `CHANGELOG.md`, `README.md`,
      `CONTRIBUTING.md`, `guides/**/*.md` and `specs/issue-42-enriched-spec.md`)
- [ ] AC-3: `README.md § Installation` pins `~> 0.1.11` (mechanical — no red test; verified by `grep -c '"~> 0.1.11"' README.md` returning `1` and `grep -c '0.1.10' README.md` returning `0`)
- [ ] AC-4: `guides/functions.md § Where Conditions` documents `:in` with both value forms and the `ArgumentError` sentence, and `§ List Functions` names membership (mechanical — no red test; verified by `grep -n ':in,\|unsupported where condition\|membership' guides/functions.md` returning 4 lines)
- [ ] AC-5: `guides/overview.md § Getting Started` pins `~> 0.1.11` (mechanical — no red test; verified by `grep -c '"~> 0.1.11"' guides/overview.md` returning `1`)

##### Green checks
1. `mix consistency` clean (code-issue); `mix test` — full suite green
   (review-issue runs the suite)
<!-- section:DOC-1:end -->
<!-- section:COR-1:start -->
### COR-1 — Core · `:in` comparator and raising condition catch-alls
Depends on: DOC-1

#### Documentation references
- `guides/functions.md § Query Options` › `§ Where Conditions` (as edited by `DOC-1`)
- `AGENTS.md § Key Patterns` › Silent catch-alls; `where` / `or_where` parity

#### Implementation details
##### Acceptance criteria
- [ ] AC-1: Given 100 sample products, when `Aurora.Ctx.Core.list/3` is called with `where: {:reference, :in, ["item_001", "item_045", "item_063"]}`, then it returns exactly those 3 products
- [ ] AC-2: Given 100 sample products, when `Aurora.Ctx.Core.list/3` is called with `where: {:reference, :in, "item_001,item_045,item_063"}`, then it returns exactly those 3 products
- [ ] AC-3: Given 100 sample products, when `Aurora.Ctx.Core.list/3` is called with `where: {:reference, :eq, "item_090"}` and `or_where: {:reference, :in, ["item_001", "item_045"]}`, then it returns 3 products; the same call with `or_where: {:reference, :in, "item_001,item_045"}` returns 3 products
- [ ] AC-4: Given 100 sample products, when `Aurora.Ctx.Core.list/3` is called with `where: {:reference, :in, []}`, then it returns `[]`
- [ ] AC-5: When `Aurora.Ctx.Core.list/3` is called with `where: {:reference, :unknown, "item_001"}`, then it raises `ArgumentError` with the message `unsupported where condition: {:reference, :unknown, "item_001"}`
- [ ] AC-6: When `Aurora.Ctx.Core.list/3` is called with `or_where: {:reference, :unknown, "item_001"}`, then it raises `ArgumentError` with the message `unsupported or_where condition: {:reference, :unknown, "item_001"}`
- [ ] AC-7: When `Aurora.Ctx.Core.list/3` is called with `where: {:reference, :in, 5}` (neither list nor binary), then it raises `ArgumentError` with the message `unsupported where condition: {:reference, :in, 5}`; the same value under `or_where:` raises with `unsupported or_where condition: {:reference, :in, 5}`
- [ ] AC-8: `mix.exs` declares `@version "0.1.11"` (mechanical — no red test; verified by `grep -n '@version "0.1.11"' mix.exs` returning 1 line)
- [ ] AC-9: the `Aurora.Ctx.QueryBuilder` `@moduledoc` and the `options/2` `@doc` list `:in` and the `ArgumentError` raise (mechanical — no red test; verified by `grep -n '`:in`\|ArgumentError' lib/aurora/ctx/query_builder.ex` listing the four doc lines of Core changes 7–8 and the two raising catch-alls, and `mix doctor` passing)

##### Test ports
- `Aurora.Ctx.Core.list/3` · in: `(Aurora.Ctx.Repo, Aurora.Ctx.Test.Support.Inventory.Product, keyword())` with `:where` / `:or_where` · out: `[Product.t()]`, raises `ArgumentError` on an unsupported condition · existing (`lib/aurora/ctx/core.ex`, `list/3`, which pipes through `QueryBuilder.options/2`)
- `Aurora.Ctx.QueryBuilder.options/2` · in: `(Ecto.Query.t(), keyword())` · out: `Ecto.Query.t()` · existing (`lib/aurora/ctx/query_builder.ex`, `options/2`); exercised through `Core.list/3`, never asserted on the query struct

##### Red tests (write first; each must fail before implementation)
All rows: `add to test/cases/core_test.exs`, as new `test` blocks placed directly after `test "Test list filter functionality - where and or_where"`. The file already has `use Aurora.Ctx.Test.RepoCase` and the aliases `Core`, `Repo`, `Product`.

| AC | Placement | Setup | Test file | Test name | Assertion sketch |
|---|---|---|---|---|---|
| AC-1 | add to | `delete_all_products()`, `create_sample_products(100)` | test/cases/core_test.exs | "Test list filter - where :in with a list" | `assert Repo \|> Core.list(Product, where: {:reference, :in, ["item_001", "item_045", "item_063"]}, order_by: :reference) \|> Enum.map(& &1.reference) == ["item_001", "item_045", "item_063"]` |
| AC-2 | add to | same | test/cases/core_test.exs | "Test list filter - where :in with a comma-separated binary" | same assertion with `where: {:reference, :in, "item_001,item_045,item_063"}` |
| AC-3 | add to | same | test/cases/core_test.exs | "Test list filter - or_where :in with a list and a comma-separated binary" | `assert Repo \|> Core.list(Product, where: {:reference, :eq, "item_090"}, or_where: {:reference, :in, ["item_001", "item_045"]}) \|> Enum.count() == 3`; the same with `or_where: {:reference, :in, "item_001,item_045"}` `== 3` |
| AC-4 | add to | same | test/cases/core_test.exs | "Test list filter - where :in with an empty list returns no records" | `assert Core.list(Repo, Product, where: {:reference, :in, []}) == []` |
| AC-5 | add to | none | test/cases/core_test.exs | "Test list filter - unsupported where condition raises" | `assert_raise ArgumentError, ~s(unsupported where condition: {:reference, :unknown, "item_001"}), fn -> Core.list(Repo, Product, where: {:reference, :unknown, "item_001"}) end` |
| AC-6 | add to | none | test/cases/core_test.exs | "Test list filter - unsupported or_where condition raises" | `assert_raise ArgumentError, ~s(unsupported or_where condition: {:reference, :unknown, "item_001"}), fn -> Core.list(Repo, Product, or_where: {:reference, :unknown, "item_001"}) end` |
| AC-7 | add to | none | test/cases/core_test.exs | "Test list filter - :in with a value neither list nor binary raises" | `assert_raise ArgumentError, "unsupported where condition: {:reference, :in, 5}", fn -> Core.list(Repo, Product, where: {:reference, :in, 5}) end`; `assert_raise ArgumentError, "unsupported or_where condition: {:reference, :in, 5}", fn -> Core.list(Repo, Product, or_where: {:reference, :in, 5}) end` |

##### Core changes
1. `lib/aurora/ctx/query_builder.ex` `where_condition/2` — two new clauses, placed after the clause `defp where_condition({field, :ilike, value}, query),` and before the clause `defp where_condition({field, :between, start_value, end_value}, query),`, verbatim:
   ```elixir
   defp where_condition({field, :in, values}, query) when is_list(values),
     do: from(q in query, where: field(q, ^field) in ^values)

   defp where_condition({field, :in, values}, query) when is_binary(values),
     do: where_condition({field, :in, String.split(values, ",")}, query)
   ```
2. `lib/aurora/ctx/query_builder.ex` `where_condition/2` — catch-all changed (behaviour change, AC-5, AC-7). Replace `defp where_condition(_where_condition, query), do: query` with, verbatim:
   ```elixir
   defp where_condition(condition, _query),
     do: raise(ArgumentError, "unsupported where condition: #{inspect(condition)}")
   ```
3. `lib/aurora/ctx/query_builder.ex` `or_where_condition/2` — two new clauses, placed after the clause `defp or_where_condition({field, :ilike, value}, query),` and before the clause `defp or_where_condition({field, :between, start_value, end_value}, query),`, verbatim:
   ```elixir
   defp or_where_condition({field, :in, values}, query) when is_list(values),
     do: from(q in query, or_where: field(q, ^field) in ^values)

   defp or_where_condition({field, :in, values}, query) when is_binary(values),
     do: or_where_condition({field, :in, String.split(values, ",")}, query)
   ```
4. `lib/aurora/ctx/query_builder.ex` `or_where_condition/2` — catch-all changed (behaviour change, AC-6, AC-7). Replace `defp or_where_condition(_or_where_condition, query), do: query` with, verbatim:
   ```elixir
   defp or_where_condition(condition, _query),
     do: raise(ArgumentError, "unsupported or_where condition: #{inspect(condition)}")
   ```
5. `option/2` and its catch-all `defp option(query, _option), do: query` stay unchanged.
6. `@spec`: unchanged for `where_condition/2`, `or_where_condition/2` and `options/2`. No caller changes: `Aurora.Ctx.Core` calls `QueryBuilder.options/2` in `list/3`, `count/3`, `get/4`, `get!/4`, `get_by/4` and `get_by!/4` and passes the caller's options through; no `generate_function/1` clause in `lib/aurora/ctx.ex` builds a `:where` value.
7. `@moduledoc` of `Aurora.Ctx.QueryBuilder`, `## Supported Filter Operations` — insert after the line
   ```
   - Range queries: `:between`
   ```
   verbatim:
   ```
   - Membership: `:in`, with a list of values or a comma-separated binary
   ```
   and insert after the line `- Dynamic expressions for complex logic` (the last item of that list, before the blank line and `## Examples`), verbatim:
   ```

   A `:where` / `:or_where` condition that matches none of these forms raises `ArgumentError`.
   ```
8. `@doc` of `options/2`, `### Filtering` › `:where` — insert after the two lines
   ```
       - Range operator:
         - `:between` - Value should be within a start/end range
   ```
   verbatim:
   ```
       - Membership operator:
         - `:in` - Field value is one of a list of values, or of a comma-separated binary split on `","`
   ```
   and insert, between the `## Returns` block and the closing `"""`, verbatim:
   ```
   ## Raises

   `ArgumentError` - A `:where` / `:or_where` condition matches none of the supported forms

   ```
9. `mix.exs` — replace `@version "0.1.10"` with `@version "0.1.11"`.
10. Fixtures: none. `test/support/helper.ex` `create_sample_products/1` already yields references `item_001` … `item_100` for 100 products.

##### Green tests
1. The red tests above pass, unmodified (code-issue runs these, targeted)
2. `mix test` — full suite green (review-issue runs this; code-issue runs
   only this section's test files)
3. `mix compile --warnings-as-errors` clean
<!-- section:COR-1:end -->

---

### Out of Scope
- Trimming whitespace around the parts of a comma-separated `:in` binary: the binary is split on `","` exactly as written.
- The `option/2` catch-all (an unknown query option key) keeps ignoring its input.
- `or_where_condition/2` applying a `%Ecto.Query.DynamicExpr{}` with `where:` instead of `or_where:`: unchanged by this issue.
- Tests through generated functions (`list_products/1` and siblings): they delegate to `Aurora.Ctx.Core.list/3`, which `COR-1` tests directly.
- Publishing the 0.1.11 package to Hex and tagging `v0.1.11`.
<!-- enriched-spec:end -->
