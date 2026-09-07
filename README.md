<h1 align="center">Clean Code Skills</h1>

<p align="center">
  Agent skills that make coding agents write like senior engineers.<br/>
  Stop slop before it is written, remove the slop already in your codebase, and prove both with a report.
</p>

<p align="center">
  <a href="https://skills.sh/MammadovEshgin/clean-code-skill"><img alt="skills.sh" src="https://skills.sh/b/MammadovEshgin/clean-code-skill"></a>
  <a href="https://github.com/MammadovEshgin/clean-code-skill/releases"><img alt="version" src="https://img.shields.io/github/v/tag/MammadovEshgin/clean-code-skill?label=version&color=2ea44f"></a>
  <a href="LICENSE"><img alt="license" src="https://img.shields.io/github/license/MammadovEshgin/clean-code-skill?color=blue"></a>
  <a href="https://agentskills.io"><img alt="agent skills" src="https://img.shields.io/badge/Agent%20Skills-compatible-6f42c1"></a>
</p>

Five small, composable [Agent Skills](https://agentskills.io) for Claude Code, Codex, Cursor, and any other skills-aware agent. One loads itself whenever code is written. Four you type when you need them. Every run ends with a short, diff-backed report.

They are built from the best public thinking on agent-written code (Matt Pocock's skills, John Ousterhout's *A Philosophy of Software Design*, Anthropic's and OpenAI's 2026 guidance, and the engineers whose posts seeded this repo), compressed to what still changes a strong model's behaviour. See [Credits](#credits).

## Quickstart (30-second setup)

1. Run the skills.sh installer from the repo you want to improve:

   ```bash
   npx skills add MammadovEshgin/clean-code-skill
   ```

2. Select all five skills and the agents you use.

3. In your agent, run `/clean-code-setup` once. It wires complexity and dead-code lint gates into your repo, adds one `check` command, creates `CODING_STANDARDS.md`, and proves each gate fails on a violation before passing again.

4. Done. `clean-code` now fires on its own whenever code is written or changed. `/deslop`, `/interrogate`, and `/clean-code-review` are there when you type them.

## Install as a Claude Code plugin

Prefer a managed bundle that updates when a new version ships? Inside Claude Code:

```
/plugin marketplace add MammadovEshgin/clean-code-skill
/plugin install clean-code@mammadoveshgin
```

Or from your shell:

```bash
claude plugin marketplace add MammadovEshgin/clean-code-skill
claude plugin install clean-code@mammadoveshgin
```

Two ways to install, two philosophies:

- **skills.sh** copies the skills into your project so you can edit them and make them your own.
- **The plugin** keeps them as a read-only, always-current bundle. Commands are namespaced: `/clean-code:deslop`, `/clean-code:interrogate`, and so on.

> [!NOTE]
> Windows users: `.\scripts\install.ps1 -Global` installs everywhere. The skills' own scripts run under Git Bash, which ships with Git for Windows. A plain copy of `skills/*` into any host's skills directory also works; see [Compatibility](#compatibility).

## Why These Skills Exist

Agents rarely fail at syntax. They fail by adding: a narration comment on every line, a helper with one caller, a `try/catch` that swallows, a null check on a value the type guarantees, a fallback that hides a failure, a stub "for later", a test that asserts a mock was called. Each piece looks finished. Together they are **slop**: code that works, passes a glance, and degrades the codebase at machine speed.

Telling a model "write clean code" does nothing; it already believes it does. These skills exist to fix six specific failure modes.

### #1: The Agent Writes Slop

> "Complexity is incremental: you have to sweat the small stuff."
>
> John Ousterhout, [A Philosophy of Software Design](https://web.stanford.edu/~ouster/cgi-bin/book.php)

**The Problem**: every change adds a little ceremony, and a coding agent makes hundreds of changes a day.

**The Fix** is [`clean-code`](./skills/clean-code/SKILL.md), a model-invoked skill that loads whenever code is written or changed. It runs a six-step loop (understand, shape, write, verify, interrogate, report) and holds the change to seven hard gates:

- **Surgical**: every changed line traces to the request.
- **Zero dead code**: no unused symbols, stubs, commented-out code, or compatibility shims.
- **Comments carry information**: a comment stays only when it says what the code cannot.
- **Structure follows need**: no helper with one caller, no interface with one implementation, no option nobody sets.
- **Boundaries validate, internals trust**: errors surface; nothing swallows.
- **Tests earn their place**: a test exists when a plausible bug would make it fail.
- **Evidence before done**: the check ran in this session and passed.

It is short by design, under 160 lines, at the altitude a senior engineer talks to another senior engineer. Depth lives one link away: [RED-FLAGS.md](./skills/clean-code/RED-FLAGS.md), [COMMENTS.md](./skills/clean-code/COMMENTS.md), [STRUCTURE.md](./skills/clean-code/STRUCTURE.md), [ERRORS.md](./skills/clean-code/ERRORS.md), [TESTS.md](./skills/clean-code/TESTS.md).

### #2: The Codebase Already Has Slop

> "Audit this repository for low-value code: redundant tests, trivial wrappers, dead abstractions, duplicate helpers, stale comments, and unnecessary ceremony. Verify each removal is safe."
>
> Emanuele Di Pietro, [on X](https://x.com/emanueledpt/status/2096366700560363931)

**The Problem**: months of agent output are already merged. Nobody wants to hand-review ten thousand lines, and a blind "clean this up" prompt changes behaviour as often as it removes noise.

**The Fix** is [`/deslop`](./skills/deslop/SKILL.md). Give it a file, a directory, a git range, or `repo`. It locks behaviour first (existing tests, plus characterization tests where coverage is thin), then works through nine passes in a fixed order: dead code, comments, abstractions, defensive paranoia, duplication, naming, tests, filler, complexity hotspots. One category per pass, typecheck and tests after each, revert on red. Anything that looks like a bug goes into "Found, not changed" instead of being fixed on the sly.

```
/deslop src/orders          # start with a module you know
/deslop src                 # then the tree
/deslop repo                # then everything, directory by directory
/deslop main                # or just the changes since main
```

<details>
<summary>What a run looks like</summary>

Input: a 39-line file with banner comments, line-by-line narration, a one-call helper, a null check the type forbids, a swallowing `try/catch`, commented-out code, a `console.log`, and a vague TODO.

Output:

```ts
export function calculateTotal(items: { price: number }[]): number {
  let total = 0;
  for (const item of items) {
    total += item.price;
  }
  return total;
}

export function applyDiscount(total: number, percent: number): number {
  return total - (total * percent) / 100;
}
```

```
## Deslop Report
Scope       src/pricing.ts · 1 file inspected · 1 file changed
Diff        +2 / -30 lines · net -28
Passes      dead code 2 · comments 12 · abstractions 1 · defensive 2 · duplication 0 · naming 0 · tests 0 · filler 0 · hotspots 0
Gates       typecheck pass (after every pass) · lint n/a · characterization 6/6 → 6/6
Complexity  n/a (no eslint in the repo)
Tools       n/a (no knip or eslint in the repo)
Verdict     behaviour preserved · no passes reverted
```

The test file next to it was out of scope, so the run left it alone and listed its tautological, duplicate, and framework-only tests under "Found, not changed".

</details>

### #3: "Done" Is Declared Too Early

> "Prefer deleting over simplifying, simplifying over optimizing, and optimizing over automating. It might be done too. You don't HAVE to go and make changes. If it's good, leave it alone."
>
> George Pickett, [on X](https://x.com/georgepickett/status/2095979879137460640)

**The Problem**: the feature works, the tests pass, and the diff still carries the scaffolding the agent built to get there.

**The Fix** is [`/interrogate`](./skills/interrogate/SKILL.md). It restates the purpose in one sentence, challenges every weak assumption, asks what can be deleted entirely and what becomes simpler once that is gone, then makes the cuts in that order of preference and verifies. "Nothing to change" is a valid answer. The same interrogation is step five of the `clean-code` loop, so it runs on every change even when you never type it.

### #4: The Author Reviews Its Own Work

> "A fresh context improves code review since Claude won't be biased toward code it just wrote."
>
> Anthropic, [Claude Code best practices](https://code.claude.com/docs/en/best-practices)

**The Problem**: the session that wrote the code carries the reasoning that justified every shortcut. Asked to review, it approves.

**The Fix** is [`/clean-code-review`](./skills/clean-code-review/SKILL.md). It runs in a forked, fresh context and sees only the diff and the standards. Findings come back on three axes, each with file, line, the named flag, the quoted lines, and the fix:

- **Slop**: tells from the catalog, reported as violations.
- **Design**: shallow modules, information leakage, pass-throughs, swallowed errors, tests that reach past the interface. Judgement calls, labelled as such.
- **Scope**: changed lines the request does not explain; requirements the spec asked for that are missing.

```
/clean-code-review main
/clean-code-review main docs/specs/rate-limit.md
```

It filters to what affects correctness, maintainability, or a documented standard. A reviewer told to find gaps will find some; chasing every one is how over-engineering creeps back in.

> [!TIP]
> When the agent does something you dislike, write one line in `CODING_STANDARDS.md`. The review and the writing skill read it on every run, and it overrides their defaults. Date the line; delete it when a linter enforces it. Every mistake happens once. (The pattern is Matt Pocock's: notice, write it down, let review enforce it.)

### #5: Prose Asks, Linters Insist

> "Just tell the LLM it has to pass cyclomatic complexity lint and it will write simpler code."
>
> Alex Graveley, [on X](https://x.com/alexgraveley/status/2092647694816707042)

**The Problem**: a rule in a Markdown file is advice. A model under pressure to finish will rationalise past advice.

**The Fix** is [`/clean-code-setup`](./skills/clean-code-setup/SKILL.md), run once per repo. It merges gates into the linter you already have (complexity 10, nesting 3, parameters 4, unused symbols, empty catches, debug statements, vague TODOs) for TypeScript/JavaScript, Python, Go, and Rust; adds dead-code tooling (`knip`, `ruff`, `deadcode`, `rustc` lints); creates one `check` command; writes `CODING_STANDARDS.md`; optionally installs a format-on-edit hook; and then proves each gate bites by adding a violation, watching the check fail with the rule named, and watching it pass again.

On a codebase that already exceeds the thresholds, it does what Ben Vinegar did on a real repo: audit, split the 91-path dispatcher into focused handlers (91 to 12, behaviour preserved), then set the lint ceiling just above the current maximum so nothing is grandfathered, and ratchet it down as hotspots fall. `scripts/complexity.sh` finds the maximum and the hotspots; `/deslop`'s ninth pass splits them.

For TypeScript, a second kind of gate matters: type evidence. Dillon Mulroy's [anti-slop](https://github.com/dmmulroy/anti-slop) Oxlint rules reject every way a model fabricates a type (widen then assert, chained casts, `unknown` in signatures, `typeof` narrowing away from the boundary, module mocking). This repo adopted that framing in its rules and `/clean-code-setup` offers to vendor the plugin.

### #6: Tests That Cannot Fail

> "Tests verify behavior through public interfaces, not implementation details. Code can change entirely; tests shouldn't."
>
> Matt Pocock, [tdd skill](https://github.com/mattpocock/skills/blob/main/skills/engineering/tdd/SKILL.md)

**The Problem**: agents produce tests by volume. Tests of getters, of the framework, of private helpers, of a mock being called, and tests whose expected value is computed the same way as the code. They cost runtime, break on every refactor, and catch nothing.

**The Fix** is a hard gate in `clean-code` and a decision list in [TESTS.md](./skills/clean-code/TESTS.md): a test exists when a plausible bug would make it fail at the public seam and a caller would care. Level (unit, integration, end-to-end, contract, property) is chosen by where the behaviour is observable, not by habit. `/deslop`'s seventh pass deletes tests that cannot fail and names the remaining coverage for each deletion.

### Summary

Discipline while writing, gates that insist, cleanup that preserves behaviour, review with fresh eyes, and a report at the end of every run. Software fundamentals matter more with agents, not less; these skills make them repeatable.

## Every Run Ends With A Report

```
## Clean Code Report
Scope       add retry to webhook delivery · 3 files
Diff        +41 / -87 lines · net -46
Removed     dead code 12 · comments 19 · debug statements 3 · abstractions 1
Gates       typecheck pass · lint pass · tests 58/58
Complexity  max 7 · over budget 0 · erosion 0%
Left        src/legacy/export.ts has 40 lines of commented-out code (out of scope)
Verdict     ready
```

Ten lines or fewer. The numbers come from two scripts and from the commands the agent actually ran:

- [`scripts/diff-stats.sh`](./skills/clean-code/scripts/diff-stats.sh): a deterministic pass over the git diff. Lines, comments, commented-out code, debug statements, TODOs, suppressions.
- [`scripts/complexity.sh`](./skills/clean-code/scripts/complexity.sh): every function's cyclomatic complexity through the linter the repo already has (ESLint, Ruff, gocyclo), the hotspots, and **erosion**: the share of complexity that sits in functions over the budget. Erosion is the metric [SlopCodeBench](https://arxiv.org/abs/2603.24755) uses to show that agent code is twice as eroded as human code and gets worse with every iteration; tracking it per change is how you see slop before it is load-bearing.

A gate that did not run says `n/a`, never `pass`. `Left` is where scope discipline shows: what was noticed and deliberately not touched.

### Measured, not asserted

`evals/run.sh` runs `/deslop` on fixtures with planted slop in a fresh Claude Code session and checks the result mechanically: behaviour test still passes, every planted pattern gone, file under a line ceiling. Two fixtures today (TypeScript, Python); add one from your own codebase. [docs/COMPARISON.md](./docs/COMPARISON.md) sets this repo against the alternatives people install, layer by layer, including where it is weaker.

## Built For 2026 Models

Instruction files accumulate handholding that weaker models needed. In July 2026 Anthropic removed over 80% of Claude Code's system prompt for Claude 5-generation models, replacing "default to writing no comments" with "write code that reads like the surrounding code: match its comment density, naming, and idiom". In September 2026 OpenAI's Codex team told users to strip itinerary-style recipes, blanket "always run tests" nudges, and "ask first" gates from their skills, and to keep short triggers, progressive disclosure, and explicit completion criteria.

These skills follow that calibration. Kept: hard gates with a testable standard, a completion criterion for every skill, deterministic lint gates, the report, and a catalog of named flags. Left out: recipes for judgement calls, prohibition walls where "match the surrounding code" is enough, "read everything first" mandates. Still guarded explicitly, because Anthropic's own prompting guide still lists them as tendencies of current models: over-engineering, defensive paranoia, unnecessary tests, scope creep.

Re-audit on each model release: run `/interrogate skills/` in a checkout of this repo and delete whatever the new model does correctly unprompted. `scripts/check.sh` enforces the structural limits.

## Reference

Skills split on one axis: who can invoke them. **User-invoked** skills are reachable only when you type them; their job is to orchestrate. **Model-invoked** skills can be invoked by you or reached for automatically by the agent when the task fits; they hold the reusable discipline.

**Model-invoked**

- **[clean-code](./skills/clean-code/SKILL.md)**: the discipline for writing and changing code. Loop, seven hard gates, writing rules, complexity budget, done gate, report.

**User-invoked**

- **[deslop](./skills/deslop/SKILL.md)** `[path | git-range | repo]`: remove slop from existing code in nine behaviour-preserving passes, with tool-backed before/after numbers.
- **[interrogate](./skills/interrogate/SKILL.md)** `[path | git-range]`: challenge a finished change from first principles. Delete, simplify, stop.
- **[clean-code-review](./skills/clean-code-review/SKILL.md)** `[base-ref] [spec-path]`: fresh-context review on three axes. Reports, does not edit.
- **[clean-code-setup](./skills/clean-code-setup/SKILL.md)** `[--no-hook]`: lint gates, one check command, `CODING_STANDARDS.md`, optional hook, proof that the gates bite.

**Reference files** (loaded on demand by the skills, one link deep)

- **[RED-FLAGS.md](./skills/clean-code/RED-FLAGS.md)**: the catalog. AI slop tells by category, Ousterhout's fourteen design red flags, Fowler's smell baseline, complexity signals. Each with its fix.
- **[COMMENTS.md](./skills/clean-code/COMMENTS.md)**: what to delete, what to keep, with before/after examples and language notes.
- **[STRUCTURE.md](./skills/clean-code/STRUCTURE.md)**: deep modules, module and project layout, dependency direction, what not to create, a new-project checklist, language notes.
- **[ERRORS.md](./skills/clean-code/ERRORS.md)**: define errors out of existence, mask, aggregate, crash; boundary validation; per-language idiom.
- **[TESTS.md](./skills/clean-code/TESTS.md)**: which tests to write and not write, seams, anti-patterns, mocking policy, red before green.

**Templates and scripts**

- [`skills/clean-code-setup/templates/`](./skills/clean-code-setup/templates/): lint gates for ESLint, Ruff, golangci-lint, and Rust; `CODING_STANDARDS.md`; a `CLAUDE.md` snippet; the format-on-edit hook.
- [`skills/clean-code/scripts/diff-stats.sh`](./skills/clean-code/scripts/diff-stats.sh) and [`complexity.sh`](./skills/clean-code/scripts/complexity.sh): the numbers behind every report.
- [`evals/`](./evals/): fixtures with planted slop and a runner that checks a real agent run mechanically.
- [`scripts/install.sh`](./scripts/install.sh), [`scripts/install.ps1`](./scripts/install.ps1): copy or symlink the skills into `.claude/skills`, `.agents/skills`, `.cursor/skills`.
- [`scripts/check.sh`](./scripts/check.sh): validates every skill against the Agent Skills limits and this repo's own rules.

Worked examples, recipes (legacy repo in a day, PR gate in CI, writer and reviewer in two sessions), Windows notes, and troubleshooting: [docs/USAGE.md](./docs/USAGE.md).

## Compatibility

| Host | Install | Notes |
|---|---|---|
| Claude Code | skills.sh, plugin, or script | Full support, including the forked review context and the format-on-edit hook. |
| Codex | skills.sh or `scripts/install.sh --codex` | `agents/openai.yaml` ships with every skill; user-invoked skills are marked implicit-invocation-off. |
| Cursor, OpenCode, Gemini CLI, Antigravity, others | skills.sh, or copy `skills/*` into the host's skills directory | Frontmatter fields a host does not know are ignored. |
| Windows | `scripts/install.ps1` | Skill scripts run under Git Bash. |

## Credits

The full annotated list is in [docs/SOURCES.md](./docs/SOURCES.md). The largest debts:

- **[Matt Pocock](https://github.com/mattpocock/skills)**: deep modules, seams and adapters, the `tdd` test discipline, two-axis review, `CODING_STANDARDS.md` as the compounding loop, the model-invoked versus user-invoked split, and `writing-great-skills`.
- **John Ousterhout**, *A Philosophy of Software Design*: complexity, deep modules, the red flags, define errors out of existence, comments as a design tool.
- **Anthropic**: skill authoring best practices, Claude Code best practices, the Claude 5 context-engineering post, the prompting guide's agentic-coding sections.
- **OpenAI Codex DX** (Eric Provencher): "Rethinking skills and prompts for GPT-6 Astra".
- **George Pickett, Emanuele Di Pietro, Ben Vinegar, Alex Graveley, Manish Kumar**: the posts that seeded this repo. Ben Vinegar's complexity-ceiling pull requests are the model for the ratchet.
- **Dillon Mulroy**, [anti-slop](https://github.com/dmmulroy/anti-slop): types as evidence; the `SAFETY:` convention; no module mocking.
- **SlopCodeBench** (SprocketLab): the erosion and verbosity metrics, and the finding that quality prompts help at first and then degrade without refactoring checkpoints.
- **Martin Fowler**, *Refactoring*; **Andrej Karpathy**'s guidelines; **Jesse Vincent**'s superpowers; **anti-slop**; **aislop**; **engineering-discipline**; **Simon Willison**; **Mitchell Hashimoto**; **Boris Cherny**.

## License

MIT. See [LICENSE](./LICENSE).
