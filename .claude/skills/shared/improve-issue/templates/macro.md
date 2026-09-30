# improve-issue · Macro sections

Read by `improve-issue` **Draft** when a Macro section is in scope. A Macro section changes what
a host context module gets from `use Aurora.Ctx` and `ctx_register_schema`: everything in
`lib/aurora/ctx.ex` — the options accepted, the list returned by `implementable_functions/2`, the
`generate_function/1` clauses and the `__before_compile__` expansion. It sits on top of Core: a
generated function only delegates.

## Rules

1. One Macro section per capability of the generated surface. It depends on every Core section
   whose function it delegates to; a change to generation alone (a naming option, an arity)
   depends only on `DOC-1`.
2. Subsection order is fixed, and is the TDD order: acceptance criteria → test ports → red
   tests → macro changes → generated-function table → green tests.
3. Generated functions carry no logic. A `generate_function/1` clause binds its arguments and
   calls `Aurora.Ctx.Core`; behaviour the clause would need belongs to a Core section.
4. A **new function type, name or arity** makes the section carry `##### Generated-function
   table`: one row per entry added to or changed in `implementable_functions/2` — `type` ·
   name pattern (`list_#{plural_infix}`, `get_#{infix}!`) · arity · the Core call it expands to.
   `implementable_functions/2` and the `generate_function/1` clauses are two lists kept by hand:
   a row with no matching clause falls to the final clause and generates **nothing**, silently,
   so every row names its clause.
5. Clause order is stated. For each new `generate_function/1` clause, name the clause it goes
   before; the last clause is the silent catch-all.
6. A host function with the same name and arity always wins over the generated one. A section
   that adds or renames a generated function states that the override still holds, and asserts
   it (`test/cases/function_override_test.exs`).
7. An option added to `ctx_register_schema` is stated with its key, accepted values, default,
   and what happens on an invalid value. Options are resolved at compile time in the host module.
8. Every name in the table is documented: `DOC-1` owns its row in `guides/functions.md`, this
   section owns the `@moduledoc` / `@doc` text in `lib/aurora/ctx.ex`. Both use the same name
   pattern.
9. At least three ACs, at least one of them an error or edge path (an invalid option, an
   overridden function, a schema whose infix collides).
10. Tests declare a context module inside the test file (`use Aurora.Ctx` +
    `ctx_register_schema(Product, …)` against `Aurora.Ctx.Test.Support.Inventory.*`) and assert
    through the generated functions, with `Aurora.Ctx.Test.RepoCase`. Never assert on the quoted
    AST. Generated code is dialyzed in the host: a new clause must produce a function whose
    success typing dialyzer accepts, which `mix consistency` checks through the test contexts.

## Template

```markdown
<!-- section:MAC-k:start -->
### MAC-k — Macro · <capability>
Depends on: <ids>

#### Documentation references
<the guides § sections specifying this behaviour>

#### Implementation details
##### Acceptance criteria
- [ ] AC-1: Given a context that declares `ctx_register_schema(<Schema>, <opts>)`, when
      `<generated_function>/<arity>` is called with <input>, then <the observable result>

##### Test ports
- `<Context>.<generated_function>/<arity>` · in: <shape> · out: <shape> ·
  existing (`file.ex`, `fun/arity`) | new

##### Red tests (write first; each must fail before implementation)
| AC | Placement | Setup | Test file | Test name | Assertion sketch |
|---|---|---|---|---|---|
| AC-1 | amend \| add to \| new file | <context module declared in the test file> | test/cases/<file>_test.exs | "<name>" | `assert <Context>.<function>(<args>) == <value>` |

##### Macro changes
1. `lib/aurora/ctx.ex` `implementable_functions/2` — <entry added or changed>
2. `lib/aurora/ctx.ex` `generate_function/1` — new clause `<exact head>` placed before
   `<clause>`
3. `ctx_register_schema` options: <key · values · default · invalid-value behaviour, or "none">

##### Generated-function table   (only when a function type, name or arity is added or changed)
| Type | Name pattern | Arity | Expands to | Clause |
|---|---|---|---|---|
| `:<type>` | `<pattern>` | <n> | `Aurora.Ctx.Core.<function>/<arity>` | `generate_function(%{type: :<type>, …})` |

##### Green tests
1. The red tests above pass, unmodified (code-issue runs these, targeted)
2. `mix test` — full suite green (review-issue runs this; code-issue runs
   only this section's test files)
3. `mix compile --warnings-as-errors` clean
<!-- section:MAC-k:end -->
```
