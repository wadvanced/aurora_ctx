---
name: improve-issue
description: >
  Partition and enrich a GitHub issue into an ordered set of self-contained,
  atomic sections — Documentation, Core, Macro — each deliverable as its
  own PR, for aurora_ctx (an Elixir macro library that generates CRUD context
  functions from Ecto schemas). Use whenever the user says "work on issue", "improve
  issue", "enrich issue", "clarify requirements", or pastes an issue URL/number.
  Always runs FIRST, before code-issue — it produces the sectioned spec that
  code-issue implements one section at a time. Presents the spec for approval
  and writes nothing until a human approves it.
---

# Skill: improve-issue

Turn a raw GitHub issue into a sectioned spec that the `normal` coder executes without guessing.
Each section is coded on its own branch and merged through its own PR.

A state machine. One run executes the steps below top to bottom — steps 1–4 once, steps 5–12
once per pass.

`aurora_ctx` is a **macro library**, not an application: a host context module declares
`use Aurora.Ctx` and `ctx_register_schema(Schema, …)`, and the library generates its CRUD,
query and pagination functions at compile time. Two layers: the **Macro** layer
(`lib/aurora/ctx.ex`) decides what is generated and under which name; the **Core** layer
(`Aurora.Ctx.Core`, `QueryBuilder`, `Pagination`) is the runtime every generated function
delegates to. That boundary shapes every spec (Writing rule 8).

## Glossary

Each term has one meaning in this file. No synonym is used.

| Term | Meaning |
|---|---|
| **spec** | `specs/issue-<n>-enriched-spec.md` on `main` — the only authoritative copy |
| **draft** | `/tmp/improve-issue-<n>-spec.md` — the text this run builds and a human approves |
| **working text** | the spec text this run is editing; it becomes the draft at Present |
| **mirror** | the pointer and Section Map copy in the issue body; regenerated, no authority |
| **store** | write the draft to the spec through `spec-store` (branch → PR → merge), which also regenerates the mirror and posts the resolution comment |
| **section** | one unit of delivery: one `<SEC-ID>`, one branch, one PR |
| **fence** | the `<!-- section:<SEC-ID>:start -->` / `:end -->` line pair that delimits a section |
| **enrichment** / **re-enrichment** | a run with no spec / a run that edits an existing spec |
| **defect**, **feedback**, **resolution comment** | defined in `../shared/improve-issue/comment-protocol.md` |
| **scope** | the sections this run drafts or changes |

## Invariants

1. Nothing is stored, and no comment is posted, until a human approves the draft's exact bytes.
   This holds on every run, including a one-word re-enrichment.
2. This skill edits no file in the repository — no documentation, no code. It writes only
   `/tmp/improve-issue-<n>-*` files; a sub-skill it invokes writes its own `/tmp` files, and the
   spec reaches the repository only through `spec-store`'s spec PR. `DOC-1` describes
   documentation edits; `code-issue` applies them.
3. This skill never creates, splits or closes an issue.
4. No question survives into the spec. A question is never answered by assumption. The spec has
   no "Open Questions" section.
5. The spec's depth is fixed at what the `normal` coder needs, at every level. The spec records
   the level, never a model name.
6. A section whose PR is merged is never changed. A section whose PR is open may be changed — and
   the user is told, because the open branch's local AC ticks will then conflict with the rewrite
   (`spec-store` § Re-enrichment while sections are in flight).
7. A `<SEC-ID>` is never renumbered and never re-used.
   Why: it is a branch name, a PR title, a review-table row, a section-log marker and a fence.
8. Facts come from GitHub and the repository, never from chat context. An existing spec is read
   through `spec-load`, never from the issue body.
9. This skill spawns no subagents. Grounding, drafting, checking and revision run inline,
   sequentially, in this run's own context. Being spawned as an agent by a caller is
   unaffected.

## Machine

`R` is this run's working record. **Steps communicate only through `R`.**

| Field | Content |
|---|---|
| `n` | the issue number |
| `mode` | `interactive` \| `non-interactive` |
| `decisions` | every `DECISION:` line of the prompt |
| `changes` | the text of a change request, or none |
| `level_arg` | the level the prompt asked for, or none |
| `level` | `normal` \| `high` \| `max` |
| `obs` | `/tmp/improve-issue-<n>-issue.json`, `/tmp/improve-issue-<n>-comments.jsonl`, the mentioned issues, `spec: /tmp/spec-<n>.md \| missing`, `prs`: per Section Map row, its PR's number and state, or none |
| `inputs` | unresolved defect and feedback comments: `id`, kind, `<SEC-ID>`, defect `Class:` |
| `scope` | `all` on an enrichment; otherwise the ids this run changes or adds — it grows as the run edits |
| `answered` | the count of questions the user answered in this run |
| `aids` | the reading aids Present built, or none |
| `unchanged` | set when the working text is byte-identical to the spec |
| `verdict` | `approved` \| `changes` \| `rejected`, or unset |
| `stored` | the merge-commit sha `spec-store` returned, or unset |
| `halt` | `{kind, payload}` — first writer wins |

Each step opens with a **pre-flight** that yields one verdict:

| Verdict | Meaning |
|---|---|
| **continue** | do the step |
| **skip** | nothing for this step this pass — next step |
| **stop** | set `R.halt` — next step |

**Universal pre-flight, before a step's own:** `R.halt` set → **skip**. Step 12 alone is exempt.
A step's `Loads` file is read only on **continue**, at most once per run.

| `halt.kind` | Payload |
|---|---|
| `relay` | a sub-skill's terminal output, verbatim |
| `decision` | one question, its options, and the facts already established |
| `blocked` | a slug, and the facts behind it |

### Question rule

A **question** is any point where two readings, two designs or two names remain after the
repository and the documentation have been read. Every step applies this rule at the point
where the question appears:

| Condition | Action |
|---|---|
| a line in `R.decisions` answers it | take that answer; continue |
| `mode = interactive` | `AskUserQuestion`; take the answer; `answered += 1`; continue |
| `mode = non-interactive` | **stop** `decision`, with the same options in the same order as the interactive question |
| the user cannot answer it | **stop** `blocked` `unresolved-question` |

Always a question, never a judgement of this skill:

- a design that removes, bypasses or makes unreachable an existing guard, validation or
  constraint;
- a design that puts logic (query building, a `Repo` call, branching on data) inside a
  generated function instead of `Aurora.Ctx.Core`;
- a design that changes an existing generated function's name, arity or return shape — every
  host context depends on them, so this is a breaking change the user must own;
- a design that changes what a silent catch-all does (`QueryBuilder`'s unmatched option or
  condition, `generate_function/1`'s last clause);
- a comparator or option specced for `where` only, or `or_where` only, when the issue does not
  say why;
- a design that has the library define a changeset or validate attributes — the host schema owns
  its changesets, the library only calls the configured function;
- documentation content that contradicts an existing rule;
- a symbol or a capability claim that stays unclassified after searching.

---

## 1 · Boot

- **Pre-flight:** continue.
- **Loads:** `../shared/turn-discipline.md`
- **Do:** parse the prompt.

  | Input | Sets |
  |---|---|
  | issue URL, `#123`, a number, or a pasted issue body carrying either | `n` |
  | the line `NON_INTERACTIVE: true` | `mode = non-interactive`; absent → `interactive` |
  | each `DECISION:` line | `decisions` |
  | a `CHANGES:` line, under `non-interactive` only | `changes`; under `interactive` the line is ignored |
  | a positional level, else a `LEVEL:` line | `level_arg` |

- **Writes:** `n`, `mode`, `decisions`, `changes`, `level_arg`.

## 2 · Load

- **Pre-flight:** continue.
- **Do**, batched in one turn:
  1. Issue: `gh issue view <n> --json title,body,state,labels`. Save it as
     `/tmp/improve-issue-<n>-issue.json`.
  2. Comments, with ids:
     ```bash
     gh api "repos/wadvanced/aurora_ctx/issues/<n>/comments" --paginate \
       --jq '.[] | {id, body}' > /tmp/improve-issue-<n>-comments.jsonl
     ```
  3. Spec: `spec-load <n>`. `STATUS: OK <sha>` → `obs.spec = /tmp/spec-<n>.md`.
     `STATUS: BLOCKED — spec-missing` → `obs.spec = missing`; this run is an enrichment.

  Then, in one more turn: fetch the title, body and state of every issue the body or a comment mentions as `#<k>` or
  by URL, one level deep;
  and, for each Section Map row of the spec, record its PR in `obs.prs`:
  `gh pr list --head <branch> --state all --json number,state`.

  The **working text** the run edits:

  | Condition | Working text |
  |---|---|
  | `changes` set and the draft file exists | the draft |
  | otherwise, `obs.spec` is a path | that file |
  | otherwise | none — drafted from nothing |

- **Writes:** `obs`.

## 3 · Gate

- **Pre-flight:** continue.
- **Loads:** `../shared/coder-model.md`
- **Do:**
  1. Resolve the level, first match: `level_arg` · the spec's `**Complexity:**` line ·
     `normal`. An unrecognised value → **stop** `blocked`
     `unknown-level`. On an enrichment, propose the level from `coder-model.md` § Choosing a
     level; the user's `level_arg` overrides it.
  2. Announce, before any other output, in the format and with the `<source>` that file
     defines: `Level: <level>[ (<source>)] · Spec/Review: <model+effort>`. A halt's output
     follows this line.

- **Writes:** `level`.

## 4 · Inputs

- **Pre-flight:** continue.
- **Loads:** `../shared/improve-issue/comment-protocol.md`, only when a line of the comments file
  matches `<!-- spec-defect #` or `<!-- review-feedback #`.
- **Do:** with that file loaded, list the unresolved defects and feedback as it defines them;
  each one is handled as it prescribes, in this run. Otherwise `inputs` is empty.
  When `obs.spec` is a path, compare every requirement in the issue body and its comments with
  the spec's ACs. A requirement no AC covers is **owed**: add the section it belongs to, or note
  it as new work for Partition.
- **Writes:** `inputs`; `scope`:

  | Condition | `scope` |
  |---|---|
  | `obs.spec = missing` | `all` |
  | `changes` set and naming no `<SEC-ID>` | every section whose PR in `obs.prs` is not merged. When there is none, `changes` is new work for Partition |
  | otherwise | the `<SEC-ID>` of every input, of every owed requirement, and every `<SEC-ID>` `changes` names. It may be empty |

## 5 · Ground

- **Pre-flight:** `scope` empty and no new work noted → skip.
- **Do:** ground every name the sections in `scope` will use. Read the guidance and the
  documentation before the code — they are the specification:

  | Read | For |
  |---|---|
  | `AGENTS.md` | the Macro / Core boundary, the silent catch-alls, documentation, testing and gate rules |
  | `guides/*.md`, `README.md` | the documented behaviour and vocabulary the issue changes (`guides/functions.md` is the generated-function reference) |
  | `CHANGELOG.md` | the `## [Unreleased]` section, and the entry style |
  | `lib/aurora/ctx.ex` | `ctx_register_schema` options, `implementable_functions/2` (every type, name pattern and arity), the `generate_function/1` clauses and their order, repo resolution |
  | `lib/aurora/ctx/core.ex` | the runtime function each generated function delegates to, its options and return shape |
  | `lib/aurora/ctx/query_builder.ex`, `lib/aurora/ctx/pagination.ex` | `option/2`, `where_condition/2`, `or_where_condition/2` clauses and their order (each ends in a silent catch-all); the pagination struct |
  | `test/support/inventory/*.ex`, `priv/repo/migrations/`, `lib/aurora/ctx/repo.ex` | the test-only schemas, their migrations and the test-only repo |
  | `test/support/{helper.ex,repo_case.ex}`, `test/cases/*_test.exs`, `test/doc_test.exs` | fixtures, the case template, existing coverage and registered doctests |

  On a re-enrichment, re-ground the working text of every section in `scope` against the
  current repository.

  **Grounding rules:**

  1. **Verify every name at its definition.** This covers functions, macro options,
     `implementable_functions/2` type atoms and name patterns, `generate_function/1` clause
     heads, query option keys, comparator atoms, pagination struct fields, and Ecto options
     passed through. Open the `def`, the `defmacro` or the package source and copy the name
     verbatim. A call site, a
     grep hit, memory and a subagent's report are not definitions. A name the section itself
     introduces is prescribed as new.
  2. **Write every file-editing instruction with that file open at the edit site.** A report is
     evidence only for the lines it quotes.
  3. **Sweep every consumer of what the issue changes**, not only the modules it edits. For a
     function type atom, `rg -n ':<sibling_atom>' lib/` and read every hit; for a Core function,
     the `generate_function/1` clauses that call it; for a query option, both the `where` and
     the `or_where` clause families. The spec never hand-rolls a check something downstream
     already performs.
  4. **An inventory is extracted, never recalled.** A statement of what a construct contains —
     the `implementable_functions/2` list, a clause family, the options a Core function reads,
     the pagination struct's fields — is produced by extracting the block and reading the
     extraction.
  5. **Classify every symbol and every capability claim** as `existing` (cited) or `new` (with
     the search terms that returned nothing). A claim such as "`or_where` already supports
     `:between`" is verified in code. One that cannot be classified is a question.
  6. **Grounding never defers.** The spec may tell the coder to copy from a named, verified
     source. It never tells the coder to discover whether a clause, an option or a generated
     function exists.

  Budget: 15–20 targeted searches plus a handful of file reads per section, the same for every
  section. The budget is a floor: it never excuses an unproven claim.

## 6 · Partition

- **Pre-flight:** `obs.spec` is a path and no new work is noted → skip.
- **Do:** build the Section Map. Ground every row added here under the Grounding rules. On a re-enrichment, existing rows keep their ids; new work
  appends ids. A row is removed only when its section has no section-log comment and no PR of
  any state.

  ### Types

  | Type | Id | One section per |
  |---|---|---|
  | Documentation | `DOC-1` | issue — exactly one, carrying every documentation edit the issue owes, and its CHANGELOG entry |
  | Core | `COR-k` | capability of the runtime that changes: `Aurora.Ctx.Core`, `QueryBuilder` or `Pagination` behaviour, with the test fixtures it needs |
  | Macro | `MAC-k` | capability of the generated surface that changes: a `ctx_register_schema` option, an `implementable_functions/2` entry, a `generate_function/1` clause, the compile-time expansion |

  A type the issue does not need is absent. `DOC-1` is absent only when the issue delivers
  neither a feature nor a fix (`documentation.md` rule 14); the Overview then says so in one
  sentence. A new generated function is normally two sections — the Core function it delegates
  to (`COR-k`), then its generation (`MAC-k`).

  ### Ids

  Unique per type, numbered per type, appended in Section Map order. A gap left by a removed
  section stays a gap.

  ### Order and dependencies

  1. Map order is Documentation, all Core, all Macro. Map order is execution order.
  2. Every section carries `Depends on:` — sibling ids, or `none`.
  3. A dependency points backward across the layer order, or sideways inside a layer. Macro
     depends on Core (only when it delegates to what that section adds). Nothing depends on
     Macro except a later Macro section. The graph is a DAG.
  4. `DOC-1` depends on nothing. Every other section's dependency chain reaches `DOC-1`: the
     first Core section — or the first Macro section when there is none before it — carries
     `Depends on: DOC-1`. With no `DOC-1`, those sections carry `none`.
  5. A section starts only when every dependency's PR is merged. Independent sections of one
     type may run in parallel.
  6. A dependency on another issue's section is written `#<n>·<SEC-ID>`. Use it when this section
     builds on code that section creates or changes; never duplicate that work.
  7. `DOC-1` is the only section that prescribes a documentation edit.
  8. Two sections that edit the same region of one code file declare a dependency: the later
     depends on the earlier.

  ### Atomicity

  Every section passes this test: *merged alone on top of its dependencies, the library compiles
  with `--warnings-as-errors`, the test fixtures migrate, and `mix consistency` and the full
  suite stay green.* When a section fails it, move content between sections until it passes.

  A Macro section that adds an `implementable_functions/2` entry owns its `generate_function/1`
  clause in the same section: an entry with no clause generates nothing, silently. `doctor`
  demands 100% `@doc` and `@spec` coverage, so a section that adds a public function carries
  both — never a later section.

  ### Scope separation

  An issue is never oversized; more work is more sections. Propose a separation only when the
  issue bundles parts with distinct goals, or a part that cannot be specced until another
  part's output exists. The proposal names each part's goal, its contents, and why it cannot be
  specced now. It is a question (Question rule). When the user separates, enrich the retained
  scope only and record the rest under `### Out of Scope`.

  ### Branch and PR title

  | Item | Form | Example |
  |---|---|---|
  | Branch | `federico/<n>-<sec>-<slug>`, `<sec>` lowercased | `federico/360-doc-1-changelog`, `federico/360-cor-2-in-comparator` |
  | PR title | `<conventional type>: … (#<n> · <SEC-ID>)` | `docs: … (#360 · DOC-1)`, `feat: … (#360 · COR-2)` |

  Every branch is unique within the issue.
  Why: `code-issue` and `review-issue` find a section's PR by an exact `gh pr list --head` probe.
  The PR title is never used to detect state: GitHub's title search matches `COR-10` for `COR-1`.

- **Writes:** `scope` (every row added or re-scoped).

## 7 · Draft

- **Pre-flight:** `scope` empty → skip.
- **Loads:** `../shared/house-conventions.md`; `../shared/improve-issue/templates/<type>.md` —
  `documentation`, `core`, `macro` — one file per type that has a section in
  `scope`, and no other.
- **Do:** write the working text: the skeleton below, and every section in `scope` from its
  type's template under its type's rules. Sections outside `scope` are copied unchanged.
  Untick every AC whose text this run changed.
  Why: `code-issue` writes a red test for the new words and `review-issue` re-proves them.

  ### Skeleton

  ```markdown
  <!-- enriched-spec:start v2 -->
  ## Enriched Spec

  **Complexity:** <R.level>

  ### Overview
  <2–3 short sentences: what this issue delivers, and which layers (Core, Macro) it touches>

  ### Section Map
  | ID | Type | Scope | Depends on | Branch | PR title |
  |---|---|---|---|---|---|
  | DOC-1 | Documentation | <file § section, …> | none | federico/<n>-doc-1-<slug> | docs: … (#<n> · DOC-1) |
  | COR-1 | Core | <capability> | DOC-1 | federico/<n>-cor-1-<slug> | feat: … (#<n> · COR-1) |

  A section starts only when every dependency is **merged**. Independent
  sections may run in parallel. Status is derived from GitHub, never recorded
  here.

  <one fenced section per Section Map row, in map order>

  ---

  ### Out of Scope
  - <what this issue explicitly does NOT include>
  <!-- enriched-spec:end -->
  ```

  The fence is the only section delimiter. Every section is wrapped in one; every fence id is a
  Section Map row; no id is fenced twice; nothing sits between one section's `:end` line and the
  next section's `:start` line.
  Why: `spec-load` extracts a section by matching the two fence lines whole. A heading match
  would take `COR-10` for `COR-1`.

  ### Writing rules

  1. **Register.** Numbered sequential steps. Short plain sentences; noun phrases, imperatives
     and tables. One instruction, one outcome. No motivating narrative, no rationale, no
     restating of the problem. A sentence the coder can lose without acting differently is
     deleted.
  2. **No optionality.** "or", "consider" and "if appropriate" never appear in an instruction.
  3. **Citations.** Every existing symbol is cited by a signature that identifies exactly one
     definition. A line number is used only when no named anchor exists. Every new symbol is
     marked `new`, with its search evidence.

     | Cited thing | Signature |
     |---|---|
     | Function | `file.ex` + `name/arity` |
     | Clause of a multi-clause function | `file.ex` + function `name/arity` + the clause head, verbatim |
     | Generated function | `ctx.ex` + its `implementable_functions/2` entry (`type`, name pattern, arity) and its `generate_function/1` clause head |
     | Macro option | `ctx.ex` + `ctx_register_schema` + the option key, and the `get_option/3` call that reads it |
     | Query option / comparator | `query_builder.ex` + the `option/2` or `where_condition/2` clause head |
     | Test schema / migration | `test/support/inventory/<schema>.ex` / `priv/repo/migrations/<file>` |
     | Documentation | `§ Section name` |

  4. **Strings.** Every message the library raises or logs is fixed: exact text, with its
     exception module.
  5. **Contract changes.** A section that changes a function's return shape, an option's
     accepted values, a struct field or a `@spec` lists the `@spec` change and every current
     caller — the `generate_function/1` clauses included — with its new handling.
  6. **Generated-name changes.** A section that adds, renames or removes a generated function
     name or arity greps that name pattern across `test/`, `guides/` and `README.md`, and lists
     every test that calls it with its new call; the documentation hits belong to `DOC-1`.
  7. **Load guarantees.** A section that consumes an option, a preload or a pagination field
     names the exact Core path that fills it, and confirms that path fills it.
  8. **Standing project rules** are restated only where the section touches them:
     - the Macro / Core boundary — a generated function binds its arguments and delegates to
       `Aurora.Ctx.Core`; Core takes the repo and the schema module as arguments and never
       resolves either;
     - `implementable_functions/2` and the `generate_function/1` clauses are kept in step: an
       entry with no clause generates nothing, silently;
     - a host function with the same name and arity overrides the generated one;
     - `where` and `or_where` stay parallel, or the reason only one applies;
     - the host schema owns its changesets: the library calls the configured changeset function
       and never defines one;
     - `Aurora.Ctx.Repo`, `test/support/inventory/*` and `priv/repo/migrations/` are test-only
       fixtures, never shipped and never referenced by library code;
     - `doctor` coverage is 100%: `@moduledoc`, `@doc` + `@spec` on the first clause of every
       public function, `@spec` on private functions, per
       `.github/prompts/module_documentation.prompt.md`;
     - the `test` alias runs `ctx.test.setup` (create + migrate) before the suite.
  9. **House conventions.** `../shared/house-conventions.md` applies to every sentence of the
     spec.
  10. **Edge cases.** Every Core and Macro section states at least one error or degraded path as
      an AC. The recurring ones: an unknown option or comparator reaching a silent catch-all;
      a `nil` query; an empty list value; a bang function raising (`Ecto.NoResultsError`,
      `Ecto.InvalidChangesetError`); a page outside the range; an invalid `ctx_register_schema`
      option that must surface at compile time rather than be swallowed.

  11. **Dependencies.** A section that adds a Hex package justifies it; `ecto_sql` and `postgrex`
      are the only runtime deps. A section that adds a test-fixture migration names its file
      under `priv/repo/migrations/` and the schema field it backs (`core.md` rule 8).

  ### Test rules

  1. **Placement**, in order of preference, stated on every red-test row:

     | Placement | When | Row says |
     |---|---|---|
     | amend an existing test | a test already exercises the port | `amend <file> "<test>"` |
     | add to an existing file | the module under test has a test file | `add to <file>`, in the matching `describe` |
     | new file | the module under test has none | `new file`, with the search that found none |

  2. **Layer.** Core behaviour → `test/cases/core_test.exs`, calling `Aurora.Ctx.Core` (or
     `QueryBuilder` / `Pagination`) directly; generated functions → the `test/cases/*_test.exs`
     file for the option exercised (`single_schema_test.exs`, `infix_schema_test.exs`,
     `option_*_test.exs`, `function_override_test.exs`), through a context module declared in
     that file; pure functions → a doctest in the module, registered in `test/doc_test.exs`.
  3. **Setup.** Every row states how the test reaches the port: `use Aurora.Ctx.Test.RepoCase`,
     the context module declared inside the test file (Macro tests), and the sample data from
     `test/support/helper.ex` (`create_sample_products/1`, `delete_all_products/0`). No mocks,
     no `Process.sleep/1`.
  4. **Assertion API follows the port.**

     | Port | Assert with |
     |---|---|
     | Core / generated function returning data | `assert` on the returned value or a pattern match on its shape — never on `inspect/1` output |
     | a query | run it through `Aurora.Ctx.Repo` and assert on the rows; never assert on the `%Ecto.Query{}` struct's internals |
     | a bang function, an invalid option | `assert_raise/2,3` naming the exception |
     | macro expansion | `function_exported?/3` on the test context, or a call — never the quoted AST |

  5. **Every Core and Macro AC has a red-test row, or ends**
     `(<mechanical|manual> — no red test; verified by <means>)`.
  6. **Parallel families.** A Core section that adds a `where` comparator names the `or_where`
     tests beside the `where` ones, or the sentence in `### Out of Scope` that excuses it.

- **Writes:** `scope` (every section this step edited).

## 8 · Check

- **Pre-flight:** `scope` empty → skip.
- **Do:** for every section in `scope`, confirm each rule under each heading below. Fix every
  failure in the working text; never note one and move on. When `R.changes` states that this
  file gained a rule after the spec was stored, check every section whose PR is not merged.

  | Check | Home of the rule |
  |---|---|
  | Atomicity | 6 · Partition § Atomicity |
  | Map complete; ids unique per type; every `Depends on:` id exists; DAG; nothing points forward | § Ids, § Order and dependencies |
  | One `DOC-1`, or the Overview's one-sentence absence; every chain reaches it | § Types, § Order and dependencies 4 |
  | `DOC-1` is the only documentation writer; shared code regions declare a dependency | § Order and dependencies 7–8 |
  | Branch unique; PR title form | § Branch and PR title |
  | Fences | 7 · Draft § Skeleton |
  | Register; no optionality | § Writing rules 1–2 |
  | Citations; new symbols carry search evidence | § Writing rules 3 |
  | Strings; contract changes; generated-name changes; load guarantees | § Writing rules 4–7 |
  | Macro / Core boundary; entry-and-clause in step; `where` / `or_where` parallel or the stated reason; generated-function table complete | § Writing rules 8, `core.md` rules 4–5, `macro.md` rules 3–4 |
  | Edge-case ACs | § Writing rules 10 |
  | Placement; layer; setup; assertion API; every AC tested or marked; parallel families | § Test rules |
  | Names verified at their definition; inventories extracted; capability claims verified; no coding-time existence check | 5 · Ground § Grounding rules |
  | Per-type rules | the loaded template's `## Rules` |
  | No guard removed without a recorded decision; zero questions remain | § Question rule, Invariant 4 |
  | No model name; `**Complexity:**` is the one level mention | Invariant 5 |
  | CHANGELOG entry in `DOC-1`, with no issue link; H-1 (no `file.md:NNN`), H-2 (generated functions named by their documented pattern), H-3 (no AC that only observes a stub), H-5, and the rest of the list | `house-conventions.md` |

  **Hedge grep**, case-insensitive, over the sections in `scope`. `|` separates alternatives; the
  spaces around it are not part of a pattern:

  ```
  confirm with | before writing | before editing | if it does not |
  identify it with | verify .* exists | say which | consider | if appropriate | \bor\b
  ```

  Every hit is removed, or justified. A `\bor\b` hit inside a quoted string is justified by that
  fact; a hit in instruction prose is never justified. The grep and its output never appear in
  the spec or the issue.

## 9 · Verify

- **Pre-flight:** `scope` empty → skip.
- **Do:** prove the working text, section by section over `scope`, in two parts. This step
  answers one question: can the `normal` coder execute this text without guessing and without
  interpreting it? The bar does not move with `R.level`.

  ### Part 1 — falsification

  Walk the written text, not the memory of researching it. Every claim is false until a command
  run during this step proves it.

  | Claim | Proof |
  |---|---|
  | an `existing` symbol | open its definition now; compare name, arity, options and field names character by character. A paraphrase an instruction is derived from fails. |
  | a `new` symbol | run the recorded search terms verbatim now. A hit falsifies the claim. |
  | a generated-function table | extract `implementable_functions/2` and the `generate_function/1` clause heads now; every row matches an entry and names an existing or prescribed clause |
  | a red-test row | `amend` — the named test exists; `add to` — the file exists; `new file` — it does not. The assertion sketch states nothing the cited source disproves. |
  | a documentation edit in `DOC-1` | the file exists; the `§` anchor is in the current doc; the text to change is there verbatim; the CHANGELOG version section exists |
  | an instruction naming a function or call site to edit | open that site now; it contains what the instruction says it contains |
  | an added, renamed or removed generated name | re-run the name-pattern grep across `test/`, `guides/` and `README.md` now; the section names every test hit with its new call, and `DOC-1` carries every documentation hit |
  | the section as a whole | no two statements disagree; no instruction disagrees with the citation it leans on |

  **Ledger.** Build a table `claim | command run | output excerpt | verdict`, one row per claim.
  A claim with no command fails. Session memory, an earlier turn's output and a subagent's report
  are not commands. The ledger is working material: it never reaches the draft, the spec, the
  issue or this run's output.

  A failed claim → re-ground it (Grounding rules), rewrite the sentence, walk the section again.

  ### Part 2 — comprehension walk

  Skip for a section that is in `scope` only through a defect of `Class:` `mechanical` or
  `oversight`. Otherwise, for every numbered instruction under `#### Implementation details` and
  every red-test row, write one checklist line from the spec text alone: the file the coder
  opens, the exact change, what it runs, the outcome it expects. Then ask of each line:

  | Question | Failure |
  |---|---|
  | Did writing the line need an inference? | yes |
  | Do the same words fit a second target, value, file or approach? | yes |
  | Does the approach touch an AGENTS.md STRICT rule (the Macro / Core boundary above all)? Quote the rule. | the approach breaks it |

  A failed line → rewrite the instruction into the one reading that survives, citing the fact or
  rule that decided it; re-ground first when the fix turns on an unverified fact; ask the three
  questions of the rewritten line. A section is presented only when every line survives
  every part that applies to it.

## 10 · Present

- **Pre-flight:** `obs.spec` is a path and the working text is byte-identical to it → set
  `unchanged`; skip.
- **Do:**
  1. Write the working text to the draft, replacing any file at that path, from `<!-- enriched-spec:start v2 -->` through
     `<!-- enriched-spec:end -->`.
  2. `R.inputs` non-empty → write the resolution comment to
     `/tmp/improve-issue-<n>-resolution.md`. Empty → delete that path.
  3. When `obs.spec` is a path, build the **reading aids**: one change line per section
     (`COR-1 unchanged · COR-2 rewritten (defect 2481937461) · MAC-1 new`), then the feedback item
     lines exactly as the resolution comment carries them. When any Section Map row has an open
     PR (`obs.prs`), add one line naming those sections: their branches' local ticks will conflict
     with this rewrite.
  4. `mode = non-interactive` → nothing more; no verdict is set.
  5. `mode = interactive` → emit the draft verbatim in chat — never a summary, an outline or
     "unchanged sections omitted" — then the reading aids. Call `ExitPlanMode` with that same
     text, prefixed by the line `Store this enriched spec for issue #<n>.`

     | Result | `verdict` |
     |---|---|
     | approved | `approved` |
     | rejected, with text | `changes`; `R.changes` = that text |
     | rejected, no text | `rejected` |

- **Writes:** `unchanged`, `aids`, `verdict`, `changes`.

## 11 · Store

- **Pre-flight:** `verdict` is not `approved` → skip.
- **Do:** invoke `spec-store <n> write /tmp/improve-issue-<n>-spec.md`, adding
  `/tmp/improve-issue-<n>-resolution.md` when that file exists. `spec-store` drives the whole
  branch → PR → checks → `merge-pr` → mirror sequence and returns one terminal line. The draft is
  stored as approved, byte for byte: nothing is redrafted, reformatted or regenerated after the
  approval. Branch on the terminal line:

  | `spec-store` returns | Action |
  |---|---|
  | `STATUS: OK <sha>` | `stored = <sha>` |
  | `STATUS: BLOCKED — concurrent-write` | the spec moved while this run drafted. Run `spec-load <n>` again; its file becomes the working text; set `verdict = changes`, `R.changes = re-apply this run's changes onto the spec now on main` |
  | `STATUS: BLOCKED — issue-unreadable` | the spec is stored; the mirror or the resolution comment is not. Invoke `spec-store`'s `--finish` repair once more. A repeat → **stop** `relay` |
  | `STATUS: BLOCKED — merged-section-modified` | **stop** `relay`, naming the merged section. The user decides: revert that section's change, or amend shipped history deliberately |
  | `STATUS: BLOCKED — spec-pr-open <url>` / `spec-pr-checks-failing <url>` / `spec-pr-checks-pending <url>` / `spec-merge-failed` | **stop** `relay`. The spec is **not** stored: its PR is still open or was refused. Nothing may be coded against it; the user resolves the PR first |
  | any other `STATUS: BLOCKED` | **stop** `relay` |

  Never trim a draft to fit a size limit. The spec file has room; length is governed by Writing
  rule 1 alone.

- **Writes:** `stored`, `verdict`, `changes`.

## 12 · Settle

- **Pre-flight:** none — always runs. The only step that ends the run or starts another pass.
- **Loads:** `../shared/escalation.md`, only to compose a `NEEDS_DECISION`.
- **Do:** first match wins.

  | # | Condition on `R` | Then |
  |---|---|---|
  | 1 | `halt.kind = relay` | output the payload verbatim; end |
  | 2 | `halt.kind = decision` | output one `NEEDS_DECISION` block; end |
  | 3 | `halt.kind = blocked` | output the facts, then `STATUS: BLOCKED — <slug>` as the last line; end |
  | 4 | `unchanged` | delete the draft file, if any; output `Nothing to change: the spec already says what issue #<n> owes.`; end |
  | 5 | `mode = non-interactive` | output `R.aids`, when set, then `STATUS: SPEC_PENDING` as the last line; end. The draft is not emitted: the launcher reads it at its path |
  | 6 | `verdict = changes` | clear `verdict`; add to `scope` every `<SEC-ID>` `R.changes` names, or every section whose PR is not merged when it names none; go to step 5 |
  | 7 | `verdict = rejected` | output `Nothing stored. Draft kept at /tmp/improve-issue-<n>-spec.md.`; end |
  | 8 | `stored` set | delete the draft file; output the summary below; end |

  ```
  ✅ Sectioned spec stored for issue #<n> — <1|0> Documentation · <c> Core · <m> Macro sections.
  📄 Documentation edits prescribed in DOC-1: <the files it edits, or "none — the issue owes no doc edit">
  ❓ Questions resolved with the user: <R.answered, or "none">
  ⚠️ <sections with an open PR whose local ticks will conflict with this rewrite, or omit the line>
  👉 Next: code-issue <n> <SEC-ID>  (Coder: <model+effort>) — the first section whose dependencies are merged.
  ```

  Rows 1–5 and 7 store nothing and post nothing.
