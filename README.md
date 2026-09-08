<h1 align="center">Clean Code Skills</h1>

<p align="center">
  Agent skills that make coding agents write, review, test, and fix code like senior engineers.<br/>
  Stop slop before it is written, rewrite the code you already have, find the bugs in it, and prove all of it with a report.
</p>

<p align="center">
  <a href="https://skills.sh/MammadovEshgin/clean-code-skill"><img alt="skills.sh" src="https://skills.sh/b/MammadovEshgin/clean-code-skill"></a>
  <a href="https://github.com/MammadovEshgin/clean-code-skill/releases"><img alt="version" src="https://img.shields.io/github/v/tag/MammadovEshgin/clean-code-skill?label=version&color=2ea44f"></a>
  <a href="LICENSE"><img alt="license" src="https://img.shields.io/github/license/MammadovEshgin/clean-code-skill?color=blue"></a>
  <a href="https://agentskills.io"><img alt="agent skills" src="https://img.shields.io/badge/Agent%20Skills-compatible-6f42c1"></a>
</p>

Eight small, composable [Agent Skills](https://agentskills.io) for Claude Code, Codex, Cursor, and any other skills-aware agent. One loads itself whenever code is written. Two you type routinely: `/finish` before every commit, `/deslop repo` once on a codebase you inherited. Three hooks make the gates run without anyone typing anything. Every run ends with a short, diff-backed report.

They are built from the best public thinking on agent-written code (Matt Pocock's skills, Addy Osmani's writing on agentic engineering, Andrej Karpathy's notes from a year of agent coding, John Ousterhout's *A Philosophy of Software Design*, Anthropic's and OpenAI's 2026 guidance, OWASP 2025) and compressed to what still changes a strong model's behaviour. See [Credits](#credits).

## Quickstart (30-second setup)

1. Run the skills.sh installer from the repo you want to improve:

   ```bash
   npx skills add MammadovEshgin/clean-code-skill
   ```

2. Select all eight skills and the agents you use.

3. In your agent, run `/clean-code-setup` once. It wires complexity, dead-code, and security lint gates into your repo, adds one `check` command, creates `CODING_STANDARDS.md`, installs three hooks (lint on every edit, fast gates before the agent stops, the full check before any commit), and proves each gate fails on a violation before passing again.

4. Done. `clean-code` now fires on its own whenever code is written or changed. Type `/finish` before each commit. On a codebase that already has slop, type `/deslop repo` once and let it work through the modules: one cleanup commit and one fix commit per module.

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
- **The plugin** keeps them as a read-only, always-current bundle. Commands are namespaced: `/clean-code:finish`, `/clean-code:deslop`, and so on.

> [!NOTE]
> Windows users: `.\scripts\install.ps1 -Global` installs everywhere. The skills' own scripts and hooks run under Git Bash, which ships with Git for Windows. A plain copy of `skills/*` into any host's skills directory also works; see [Compatibility](#compatibility).

## Why These Skills Exist

Agents rarely fail at syntax. They fail by adding: a narration comment on every line, a helper with one caller, a `try/catch` that swallows, a null check on a value the type guarantees, a fallback that hides a failure, a stub "for later", a test that asserts a mock was called, a query built from a string. Each piece looks finished. Together they are **slop**: code that works, passes a glance, and degrades the codebase at machine speed.

Telling a model "write clean code" does nothing; it already believes it does. These skills exist to fix nine specific failure modes.

### #1: The Agent Writes Slop

> "They really like to overcomplicate code and APIs, they bloat abstractions, they don't clean up dead code after themselves, etc. They will implement an inefficient, bloated, brittle construction over 1000 lines of code and it's up to you to be like 'umm couldn't you just do this instead?'"
>
> Andrej Karpathy, [on X](https://x.com/karpathy/status/2015883857489522876)

**The Problem**: every change adds a little ceremony, and a coding agent makes hundreds of changes a day.

**The Fix** is [`clean-code`](./skills/clean-code/SKILL.md), a model-invoked skill that loads whenever code is written or changed. It runs a six-step loop (understand, shape, write, verify, interrogate, report) and holds the change to eight hard gates:

- **Surgical**: every changed line traces to the request; a comment that is not understood is left alone.
- **Zero dead code**: no unused symbols, stubs, commented-out code, or compatibility shims.
- **Comments carry information**: a comment stays only when it says what the code cannot.
- **Structure follows need**: no helper with one caller, no interface with one implementation, no copy of a helper that exists elsewhere.
- **Boundaries validate, internals trust**: errors surface; nothing swallows.
- **Safe by default**: parameterized queries, no raw strings into shell, path, URL, or HTML sinks, authorization per entry point, bounded external calls, failure closes.
- **Tests can fail**: a test asserts an outcome at a seam and was seen red once.
- **Evidence before done**: the check ran in this session and passed, and nothing was weakened to get there.

It is short by design, under 200 lines, at the altitude a senior engineer talks to another senior engineer. Depth lives one link away: [RED-FLAGS.md](./skills/clean-code/RED-FLAGS.md), [BUGS.md](./skills/clean-code/BUGS.md), [COMMENTS.md](./skills/clean-code/COMMENTS.md), [STRUCTURE.md](./skills/clean-code/STRUCTURE.md), [ERRORS.md](./skills/clean-code/ERRORS.md), [TESTS.md](./skills/clean-code/TESTS.md).

### #2: The Codebase Already Has Slop

> "When I look at the code, sometimes I get a heart attack. It is not always amazing code. It can be bloated, copy-pasted, awkwardly abstracted, brittle. It works, but it is gross."
>
> Andrej Karpathy, [Sequoia Ascent 2026](https://karpathy.bearblog.dev/sequoia-ascent-2026/)

**The Problem**: months of agent output are already merged. Nobody wants to hand-review ten thousand lines, a blind "clean this up" prompt changes behaviour as often as it removes noise, and removing noise is not the same as writing the code well.

**The Fix** is [`/deslop`](./skills/deslop/SKILL.md). Give it a file, a directory, a git range, or `repo`. It locks behaviour first (existing tests, plus characterization tests where coverage is thin), then works through eleven passes in a fixed order: dead code, comments, abstractions, defensive paranoia, duplication, naming, filler, complexity hotspots, **design**, tests, docs. The design pass is where the code becomes what a senior engineer would have written, not merely what is left after deleting: shallow modules merged into deep ones, leaked knowledge moved behind one interface, special cases defined away, boolean flags replaced, pass-through layers collapsed, functions beyond repair rewritten from their tests. One category per pass, typecheck and tests after each, revert on red. Then a separate audit step hunts for bugs and fixes them with a red test first.

```
/deslop repo                # the whole codebase, planned and committed slice by slice
/deslop repo --plan         # write the plan and stop
/deslop src/orders          # one module, when you want to judge the result first
/deslop main                # the changes since main
/deslop src --refactor-only # passes only, no audit
```

`repo` is the automated form. A whole codebase does not fit one context, and one giant diff can be neither reviewed nor reverted, so `/deslop repo` does what large-scale changes do everywhere: shard, then land each shard on its own. It inventories the source, measures complexity and churn, groups files into slices (a module with its tests), and orders them by risk and value. The plan goes to `.deslop/plan.md`. Then, for each slice: a fresh-context worker runs the eleven passes on that slice alone and the slice lands as `refactor(deslop): <slice>`; a second fresh-context worker audits the cleaned slice and its fixes land as `fix(audit): <slice>`, each fix with a test that was watched failing on the pre-fix code. Red gate, slice reverted, next slice. After the last slice, a structure phase fixes the layout with tool-verified moves. Stop whenever you like; `/deslop repo` resumes from the plan. The design and its sources are in [REPO.md](./skills/deslop/REPO.md).

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
Passes      dead code 2 · comments 12 · abstractions 1 · defensive 2 · duplication 0 · naming 0 · filler 0 · hotspots 0 · design 0 · docs 0
Tests       4 → 4 · deleted 0 · rewritten 0 · added 0 · probes killed 6/6
Audit       fixed 0 · reported 0
Gates       typecheck pass (after every pass) · lint n/a · check n/a
Complexity  n/a (no eslint in the repo)
Tools       n/a (no knip or eslint in the repo)
Verdict     behaviour preserved · no passes reverted
```

</details>

### #3: "Done" Is Declared Too Early

> "Prefer deleting over simplifying, simplifying over optimizing, and optimizing over automating. It might be done too. You don't HAVE to go and make changes. If it's good, leave it alone."
>
> George Pickett, [on X](https://x.com/georgepickett/status/2095979879137460640)

**The Problem**: the feature works, the tests pass, and the diff still carries the scaffolding the agent built to get there.

**The Fix** is [`/interrogate`](./skills/interrogate/SKILL.md). It restates the purpose in one sentence, challenges every weak assumption, asks what can be deleted entirely and what becomes simpler once that is gone, then makes the cuts in that order of preference and verifies. "Nothing to change" is a valid answer. The same interrogation is step five of the `clean-code` loop and step one of `/finish`, so it runs on every change even when you never type it.

### #4: The Author Reviews Its Own Work

> "A fresh context improves code review since Claude won't be biased toward code it just wrote."
>
> Anthropic, [Claude Code best practices](https://code.claude.com/docs/en/best-practices)

**The Problem**: the session that wrote the code carries the reasoning that justified every shortcut. Asked to review, it approves. Asked to find problems, it invents some.

**The Fix** is [`/clean-code-review`](./skills/clean-code-review/SKILL.md). It runs in a forked, fresh context and sees the diff, the code around it, and the standards. It reads the test changes first, because a test rewritten to match new behaviour is the signature failure of agent-written changes. Findings come back on four axes, each with file, line, the named flag, the quoted lines, and the fix:

- **Slop**: tells from the catalog, reported as violations.
- **Design**: shallow modules, information leakage, pass-throughs, swallowed errors, copies of existing helpers. Judgement calls, labelled as such.
- **Correctness**: bugs, weaknesses, and security flaws, each written as "given X, Y happens; expected Z", with severity and confidence. Only findings that survive a second reading and score 80 or more are raised, the same bar Claude Code's own review plugin uses.
- **Scope**: changed lines the request does not explain; requirements the spec asked for that are missing.

```
/clean-code-review main
/clean-code-review main docs/specs/rate-limit.md
```

> [!TIP]
> When the agent does something you dislike, write one line in `CODING_STANDARDS.md`. The review and the writing skill read it on every run, and it overrides their defaults. Date the line; delete it when a linter enforces it. Every mistake happens once. (The pattern is Matt Pocock's: notice, write it down, let review enforce it. His demonstration was one command: `echo "Tautological tests considered harmful." >> CODING_STANDARDS.md`.)

### #5: Prose Asks, Linters Insist

> "The agents do not listen to my instructions in the AGENTS.md files... I think in principle I could use hooks or slash commands to clean this up."
>
> Andrej Karpathy, [on X](https://x.com/karpathy/status/2035173492447224237)

**The Problem**: a rule in a Markdown file is advice. A model under pressure to finish will rationalise past advice, and a human under pressure will forget to type the command that checks.

**The Fix** is [`/clean-code-setup`](./skills/clean-code-setup/SKILL.md), run once per repo. It merges gates into the linter you already have (complexity 10, nesting 3, parameters 4, unused symbols, empty catches, debug statements, vague TODOs, and the security rules: Ruff `S`, `gosec`, `eslint-plugin-security`) for TypeScript/JavaScript, Python, Go, and Rust; adds dead-code tooling; creates one `check` command; writes `CODING_STANDARDS.md`; and installs three hooks:

| Hook | When | Does |
|---|---|---|
| `format-and-lint.sh` | after every edit | formats the file and lints it; findings go straight back to the agent |
| `check-on-stop.sh` | before the agent stops | runs the fast gates when files were edited; red keeps the agent working |
| `commit-gate.sh` | before any `git commit` | runs the full check; red blocks the commit |

Then it proves each gate bites by adding a violation, watching the check fail with the rule named, watching the commit gate block a fake commit, and watching it all pass again. On a codebase that already exceeds the thresholds, it sets the ceiling just above the current maximum so nothing is grandfathered, and ratchets it down as hotspots fall.

### #6: Tests That Cannot Fail

> "The agent changes behavior, then 'fixes' the test by rewriting the assertion to match the new, broken behavior."
>
> Addy Osmani, [Agentic code review](https://addyosmani.com/blog/agentic-code-review/)

**The Problem**: agents produce tests by volume. Tests of getters, of the framework, of private helpers, of a mock being called, tests whose expected value is computed the same way as the code, tests that read a file and assert it contains itself. They cost runtime, break on every refactor, and catch nothing. And when a real test gets in the way, the cheapest path to green is to weaken it.

**The Fix** is [`/test-audit`](./skills/test-audit/SKILL.md). It classifies every test in scope as keep, rewrite, merge, or delete, with the tell; rewrites implementation-coupled tests at the public seam (injecting the dependency instead of mocking the module); adds the seam tests callers depend on; and then proves the result the only way a test can be proven: it breaks the code on purpose. With StrykerJS, mutmut, cargo-mutants, or gremlins when the repo has one, by hand otherwise (negate a condition, shift a boundary, return a constant), every mutant must make the suite fail. A survivor gets a test named for the behaviour it exposed. The report says `probes killed 118/126`. `/deslop` runs it as pass 10; `/finish` runs it on the change's tests.

### #7: Bugs And Security Holes Ship

> "If your pull request doesn't contain evidence that it works, you're not shipping faster - you're just moving work downstream."
>
> Addy Osmani, [Code review in the age of AI](https://addyosmani.com/blog/code-review-ai/)

**The Problem**: agent-written code carries more logic errors and more security flaws than human code, by every study Osmani cites, and a review that lists "possible issues" without evidence is noise the team learns to ignore.

**The Fix** is [`/audit`](./skills/audit/SKILL.md). It maps every entry point in scope to the sinks it reaches, walks the catalog in [BUGS.md](./skills/clean-code/BUGS.md) (boundaries, absence, error paths, async and races, time, numbers, text, state, resources, data integrity, control flow, contracts; unbounded calls and inputs; the OWASP Top 10:2025 as tells and fixes), and writes each finding as a sentence: given this input, this happens, this was expected. A finding scores 0 to 100; below 80 it is not raised. A finding is fixed only after a loop showed the failure (a test at the seam, a request with the payload) and went red; the fix is the smallest change using the codebase's own secure pattern; the loop stays as the regression test. What cannot be proven is reported with what would prove it, never patched blind. Fixes are separate from cleanup, so a reviewer reads "same behaviour" and "new behaviour, proven" as different commits.

### #8: The Folder Structure Rots

> "...laying out the code so the next reader, human or model, knows where to find the thing they care about; keeping call stacks short and legible; keeping component boundaries well defined so a change doesn't have a huge blast radius."
>
> Addy Osmani, [Software factories](https://addyosmani.com/blog/software-factories/)

**The Problem**: `utils/` grows, features spread across `controllers/`, `services/`, and `models/`, barrels re-export subtrees, tests drift away from the code, and every module deep-imports every other. No single change causes it, so no single change fixes it.

**The Fix** lives in [STRUCTURE.md](./skills/clean-code/STRUCTURE.md): deep modules, domain folders, dependency direction, and a table of structure problems with their fixes and the way to move safely. The writing skill uses it for new files. The review names the problems. The structure phase of `/deslop repo` applies the moves that tooling can verify, one commit per move with the check green after it, and publishes the moved-path map so open branches can rebase.

### #9: Nine Steps Before Every Commit

> "Each new session begins with no memory of what came before."
>
> Anthropic, [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)

**The Problem**: interrogate, deslop, audit the tests, audit the code, run the check, review in a fresh context, apply the findings, run the check, review again. Nine steps before every commit is a workflow nobody keeps by hand, so the steps that matter get skipped on the day they matter.

**The Fix** is [`/finish`](./skills/finish/SKILL.md), one command between "it works" and `git commit`. It interrogates the diff first (a deleted function needs no cleaning), deslops what remains, makes the change's tests able to fail, hunts for bugs in the change and fixes them red-first, runs the check, hands the diff to a fresh-context reviewer, applies the findings (correctness findings are reproduced before they are fixed; weakened checks are restored), runs the check again, and reviews once more when anything changed. It leaves the working tree ready and prints one report with a suggested commit message and a line for what could not be verified; `--commit` commits when the verdict is ready. A `rethink` verdict stops it, because that is a decision, not a cleanup.

```
/finish                     # the uncommitted diff
/finish main                # the branch since main
/finish main --commit       # and commit when ready
```

### Summary

Discipline while writing, gates that insist and hooks that run them, cleanup that rewrites rather than deletes, tests that are proven with mutants, bugs and security flaws found with evidence and fixed red-first, structure that follows the domain, review with fresh eyes, one command before every commit, and a report at the end of every run. Software fundamentals matter more with agents, not less; these skills make them repeatable and, where a hook can run them, automatic.

## Every Run Ends With A Report

```
## Clean Code Report
Scope       add retry to webhook delivery · 3 files
Diff        +41 / -87 lines · net -46
Removed     dead code 12 · comments 19 · debug statements 3 · abstractions 1
Gates       typecheck pass · lint pass · tests 58/58
Complexity  max 7 · over budget 0 · erosion 0%
Unverified  nothing
Left        src/legacy/export.ts has 40 lines of commented-out code (out of scope)
Verdict     ready
```

Ten lines or fewer. The numbers come from two scripts and from the commands the agent actually ran:

- [`scripts/diff-stats.sh`](./skills/clean-code/scripts/diff-stats.sh): a deterministic pass over the git diff. Lines, comments, commented-out code, debug statements, TODOs, suppressions.
- [`scripts/complexity.sh`](./skills/clean-code/scripts/complexity.sh): every function's cyclomatic complexity through the linter the repo already has (ESLint, Ruff, gocyclo), the hotspots, and **erosion**: the share of complexity that sits in functions over the budget. Erosion is the metric [SlopCodeBench](https://arxiv.org/abs/2603.24755) uses to show that agent code is twice as eroded as human code and gets worse with every iteration; tracking it per change is how you see slop before it is load-bearing.

A gate that did not run says `n/a`, never `pass`. `Unverified` says what could not be run and why. `Left` is where scope discipline shows: what was noticed and deliberately not touched.

### Measured, not asserted

`evals/run.sh` runs the skills on fixtures with planted problems in a fresh Claude Code session and checks the result mechanically: behaviour test still passes, every planted pattern gone, file under a line ceiling, one commit per slice for `/deslop repo`, a red-first test per fix for `/audit`, and, for `/test-audit`, the check itself applies three mutants to the production code and fails unless the suite kills all three. Six fixtures today; add one from your own codebase. [docs/COMPARISON.md](./docs/COMPARISON.md) sets this repo against the alternatives people install, layer by layer, including where it is weaker.

## Built For 2026 Models

Instruction files accumulate handholding that weaker models needed. In July 2026 Anthropic removed over 80% of Claude Code's system prompt for Claude 5-generation models, replacing "default to writing no comments" with "write code that reads like the surrounding code: match its comment density, naming, and idiom". In September 2026 OpenAI's Codex team told users to strip itinerary-style recipes, blanket "always run tests" nudges, and "ask first" gates from their skills, and to keep short triggers, progressive disclosure, and explicit completion criteria.

These skills follow that calibration. Kept: hard gates with a testable standard, a completion criterion for every step, deterministic lint gates and hooks, the report, and catalogs of named flags. Left out: recipes for judgement calls, prohibition walls where "match the surrounding code" is enough, "read everything first" mandates. Still guarded explicitly, because Anthropic's own prompting guide and Karpathy's notes still list them as tendencies of current models: over-engineering, defensive paranoia, unnecessary tests, scope creep, silently cleaning up what was not understood, and reaching green by weakening the check.

Re-audit on each model release: run `/interrogate skills/` in a checkout of this repo and delete whatever the new model does correctly unprompted. `scripts/check.sh` enforces the structural limits.

## Reference

Skills split on one axis: who can invoke them. **User-invoked** skills are reachable only when you type them; their job is to orchestrate. **Model-invoked** skills can be invoked by you or reached for automatically by the agent when the task fits; they hold the reusable discipline.

**Model-invoked**

- **[clean-code](./skills/clean-code/SKILL.md)**: the discipline for writing and changing code. Loop, eight hard gates, writing rules, complexity budget, done gate, report.

**User-invoked**

- **[finish](./skills/finish/SKILL.md)** `[base-ref] [--commit]`: before a commit. Interrogate, deslop, test audit, audit, gates, fresh-context review, findings applied, one report with a suggested commit message.
- **[deslop](./skills/deslop/SKILL.md)** `[path | git-range | repo] [--plan] [--refactor-only] [--no-structure]`: rewrite existing code to the senior standard in eleven behaviour-preserving passes, then audit it, with tool-backed before/after numbers. `repo` plans the whole codebase into slices, lands a cleanup commit and a fix commit per slice, then fixes the structure.
- **[audit](./skills/audit/SKILL.md)** `[path | git-range] [--report-only]`: find bugs, weaknesses, and security flaws with evidence; fix each with a test that failed first; report what cannot be proven.
- **[test-audit](./skills/test-audit/SKILL.md)** `[path | git-range]`: delete tests that cannot fail, rewrite implementation-coupled tests at the seam, add the missing seam tests, prove the suite with mutation probes.
- **[interrogate](./skills/interrogate/SKILL.md)** `[path | git-range]`: challenge a finished change from first principles. Delete, simplify, stop.
- **[clean-code-review](./skills/clean-code-review/SKILL.md)** `[base-ref] [spec-path]`: fresh-context review on four axes, every finding verified. Reports, does not edit.
- **[clean-code-setup](./skills/clean-code-setup/SKILL.md)** `[--no-hooks]`: lint gates, one check command, `CODING_STANDARDS.md`, three hooks, proof that the gates bite.

**Reference files** (loaded on demand by the skills, one link deep)

- **[RED-FLAGS.md](./skills/clean-code/RED-FLAGS.md)**: the catalog. AI slop tells by category, Ousterhout's fourteen design red flags, Fowler's smell baseline, complexity signals. Each with its fix.
- **[BUGS.md](./skills/clean-code/BUGS.md)**: correctness, robustness, and security tells (OWASP Top 10:2025), the evidence each needs, the fix, the exclusions, the confidence rubric.
- **[REPO.md](./skills/deslop/REPO.md)**: the `/deslop repo` loop. Preflight, plan, slice order, the two worker prompts, gate, commit, structure phase, resume, finish.
- **[COMMENTS.md](./skills/clean-code/COMMENTS.md)**: what to delete, what to keep, with before/after examples and language notes.
- **[STRUCTURE.md](./skills/clean-code/STRUCTURE.md)**: deep modules, module and project layout, dependency direction, structure problems and safe moves, a new-project checklist, language notes.
- **[ERRORS.md](./skills/clean-code/ERRORS.md)**: define errors out of existence, mask, aggregate, crash; boundary validation; per-language idiom.
- **[TESTS.md](./skills/clean-code/TESTS.md)**: which tests to write and not write, seams, anti-patterns including weakened checks, mocking policy, mutation probes, red before green.

**Templates and scripts**

- [`skills/clean-code-setup/templates/`](./skills/clean-code-setup/templates/): lint gates for ESLint, Ruff, golangci-lint, and Rust; `CODING_STANDARDS.md`; a `CLAUDE.md` snippet; the three hook scripts and their settings.
- [`skills/clean-code/scripts/diff-stats.sh`](./skills/clean-code/scripts/diff-stats.sh) and [`complexity.sh`](./skills/clean-code/scripts/complexity.sh): the numbers behind every report.
- [`evals/`](./evals/): fixtures with planted slop, bugs, and trash tests, and a runner that checks a real agent run mechanically.
- [`scripts/install.sh`](./scripts/install.sh), [`scripts/install.ps1`](./scripts/install.ps1): copy or symlink the skills into `.claude/skills`, `.agents/skills`, `.cursor/skills`.
- [`scripts/check.sh`](./scripts/check.sh): validates every skill against the Agent Skills limits and this repo's own rules.

Worked examples, recipes (legacy repo in a day, overnight cleanup, PR gate in CI, writer and reviewer in two sessions), branch behaviour, Windows notes, and troubleshooting: [docs/USAGE.md](./docs/USAGE.md).

## Compatibility

| Host | Install | Notes |
|---|---|---|
| Claude Code | skills.sh, plugin, or script | Full support, including the forked review context, the fresh-context workers of `/deslop repo` and `/finish`, and the three hooks. |
| Codex | skills.sh or `scripts/install.sh --codex` | `agents/openai.yaml` ships with every skill; user-invoked skills are marked implicit-invocation-off. Without subagents, `/deslop repo` runs slices inline and resumes across sessions; `/finish` reviews inline. Hooks are Claude Code only; the gates still run through the `check` command. |
| Cursor, OpenCode, Gemini CLI, Antigravity, others | skills.sh, or copy `skills/*` into the host's skills directory | Frontmatter fields a host does not know are ignored. Same inline fallback as Codex. |
| Windows | `scripts/install.ps1` | Skill scripts and hooks run under Git Bash. |

## Credits

The full annotated list is in [docs/SOURCES.md](./docs/SOURCES.md). The largest debts:

- **[Matt Pocock](https://github.com/mattpocock/skills)**: deep modules, seams and adapters, the `tdd` test discipline, the diagnosing-bugs loop (a red-capable loop before any hypothesis), two-axis review, `CODING_STANDARDS.md` as the compounding loop, "tautological tests considered harmful", the drawer-of-cables warning about agent-maintained markdown, the model-invoked versus user-invoked split, and `writing-great-skills`.
- **[Addy Osmani](https://addyosmani.com/blog/)**: the burden of proof on the author, read test diffs first, tier review by risk, "the safety net has to live outside the model", mutation testing as a constraint, comprehension and intent debt, every AGENTS.md line traceable to a failure, rules that must hold belong in hooks and tests.
- **[Andrej Karpathy](https://x.com/karpathy)**: the catalog of what agents get wrong (wrong assumptions run with, bloated abstractions, dead code left behind, comments "cleaned up" without understanding, copy-paste, multitasking lines), success criteria over instructions, hooks over prose, the naive-then-optimize order, simplification as the thing models resist most.
- **John Ousterhout**, *A Philosophy of Software Design*: complexity, deep modules, the red flags, define errors out of existence, comments as a design tool.
- **Anthropic**: skill authoring best practices, Claude Code best practices, the Claude 5 context-engineering post, the prompting guide's agentic-coding sections, the long-running-agent harness behind `/deslop repo`, the security reviewer's evidence-and-exclusions model, and the code-review plugin's confidence rubric.
- **OWASP**, Top 10:2025, the spine of the security half of `BUGS.md`.
- **Google**, *Software Engineering at Google* ch. 22, and **Kent Beck**, *Tidy First?*: large-scale changes as independently tested, independently committed shards; structure and behaviour in separate commits.
- **OpenAI Codex DX** (Eric Provencher): "Rethinking skills and prompts for GPT-6 Astra".
- **Vinh Nguyen** (`/review` until clean), **George Pickett, Emanuele Di Pietro, Ben Vinegar, Alex Graveley, Manish Kumar, klöss** (`DONE WHEN`, `VERIFY`, `STOP RULES`): the posts that seeded and sharpened this repo.
- **Dillon Mulroy**, [anti-slop](https://github.com/dmmulroy/anti-slop): types as evidence; the `SAFETY:` convention; no module mocking.
- **SlopCodeBench** (SprocketLab): the erosion and verbosity metrics. **StrykerJS, mutmut, cargo-mutants, gremlins**: the mutation tools behind `/test-audit`.
- **Martin Fowler**, *Refactoring*; **Jesse Vincent**'s superpowers; **aislop**; **engineering-discipline**; **Simon Willison**; **Mitchell Hashimoto**; **Boris Cherny**.

## License

MIT. See [LICENSE](./LICENSE).
