# clean-code-skill

Senior-engineer discipline for coding agents. Five [Agent Skills](https://agentskills.io) that make Claude Code, Codex, Cursor, and any other skills-aware agent write code without AI slop, clean the slop already in a codebase, and prove both with numbers.

```
npx skills add MammadovEshgin/clean-code-skill
```

## The problem

Agents rarely fail at syntax. They fail by adding: a narration comment on every line, a helper with one caller, a `try/catch` that swallows, a null check on a value the type guarantees, a fallback that hides a failure, a stub "for later", a test that asserts a mock was called, an interface with one implementation. Each piece looks finished. Together they are **slop**: code that works, passes a glance, and degrades the codebase at machine speed.

Telling a model "write clean code" does nothing; it already thinks it does. What works is three layers:

1. **Discipline that fires when code is written.** A short, opinionated skill at the right altitude: hard gates, a loop, a done gate. Not a wall of prohibitions.
2. **Gates that insist.** Complexity, dead-code, and unused-symbol lint rules the agent must pass. Prose asks; a linter insists.
3. **Evidence.** Every piece of work ends with a report computed from the diff and the commands that actually ran.

## What's inside

| Skill | Who invokes it | Job |
|---|---|---|
| [`clean-code`](skills/clean-code/SKILL.md) | the agent, automatically, whenever code is written or changed | The discipline: understand, shape, write, verify, interrogate, report. Seven hard gates. Rules for simplicity, structure, naming, errors, comments, tests, types. A complexity budget. |
| [`/deslop`](skills/deslop/SKILL.md) | you | Clean an existing file, directory, or the whole repo in eight ordered, behaviour-preserving passes. Locks behaviour with tests first, verifies after every pass, reports before/after. |
| [`/interrogate`](skills/interrogate/SKILL.md) | you | Challenge a finished change from first principles. Delete, then simplify, then stop. Allowed to conclude "nothing to change". |
| [`/clean-code-review`](skills/clean-code-review/SKILL.md) | you | Review a diff in a fresh context on three axes: slop, design, scope. Reports findings that matter, with the fix. Does not edit. |
| [`/clean-code-setup`](skills/clean-code-setup/SKILL.md) | you, once per repo | Install complexity and dead-code gates for TypeScript/JavaScript, Python, Go, Rust; one `check` command; `CODING_STANDARDS.md`; an optional format-on-edit hook. Proves each gate bites. |

Reference files loaded on demand, one level deep: [RED-FLAGS.md](skills/clean-code/RED-FLAGS.md) (the catalog: slop tells, Ousterhout's red flags, Fowler's smells), [COMMENTS.md](skills/clean-code/COMMENTS.md), [STRUCTURE.md](skills/clean-code/STRUCTURE.md), [ERRORS.md](skills/clean-code/ERRORS.md), [TESTS.md](skills/clean-code/TESTS.md).

### Every skill ends with a report

```
## Clean Code Report
Scope     add retry to webhook delivery · 3 files
Diff      +41 / -87 lines · net -46
Removed   dead code 12 · comments 19 · debug statements 3 · abstractions 1
Gates     typecheck pass · lint pass · tests 58/58 · complexity max 7
Left      src/legacy/export.ts has 40 lines of commented-out code (out of scope)
Verdict   ready
```

The numbers come from [`scripts/diff-stats.sh`](skills/clean-code/scripts/diff-stats.sh) and the commands the agent ran. A gate that did not run says `n/a`, never `pass`.

## Install

**skills.sh** (Claude Code, Codex, Cursor, and other Agent Skills hosts; copies the skills so you can edit them):

```bash
npx skills add MammadovEshgin/clean-code-skill
```

**Claude Code plugin** (managed bundle, updates when this repo ships a version; commands are namespaced, e.g. `/clean-code:deslop`):

```
/plugin marketplace add MammadovEshgin/clean-code-skill
/plugin install clean-code@mammadoveshgin
```

**Script** (copy or symlink into `~/.claude/skills` or `./.claude/skills`, optionally `.agents/skills` and `.cursor/skills`):

```bash
git clone https://github.com/MammadovEshgin/clean-code-skill
cd clean-code-skill
scripts/install.sh --global            # every project; add --link to track this repo with git pull
scripts/install.sh                     # this project only (run from the target repo)
scripts/install.sh --global --codex    # also ~/.agents/skills
```

Windows: `.\scripts\install.ps1 -Global`. The skills' own scripts run under Git Bash, which ships with Git for Windows.

## Use it

### New work: nothing to type

The `clean-code` skill loads itself when code is written or changed. Ask for the feature; you get the discipline and the report.

```
Add rate limiting to POST /api/upload: 10 requests per minute per user,
429 with a Retry-After header. Tests for the limit and the header.
```

What changes compared with a bare agent: no narration comments, no `utils/rateLimit.ts` with one caller, no `try/catch` around code that cannot throw, no "for future use" options, tests at the handler seam rather than on a mock, a run of typecheck and tests before "done", and a seven-line report with the diff numbers.

### Finishing: `/interrogate`

After a feature lands and before the PR:

```
/interrogate
/interrogate main            # everything since main
/interrogate src/payments    # a directory
```

It answers four questions against the diff (purpose, weak assumptions, what can be deleted, what simplifies after that), makes the cuts in order of preference (delete, simplify, stop), verifies, and reports. "Nothing to change" is a valid outcome.

### Reviewing: `/clean-code-review`

```
/clean-code-review main
/clean-code-review main docs/specs/rate-limit.md   # also checks the diff against the spec
```

Runs in a fresh context so the reviewer is not the author. Findings are grouped by axis (slop, design, scope), each with file, line, the named flag, the quoted lines, and the fix. Verdict: merge, fix then merge, or rethink. Paste the findings back into the working session to apply them.

### Existing project: `/clean-code-setup` then `/deslop`

For a codebase that already has slop in it:

```
/clean-code-setup                 # once: lint gates, check command, CODING_STANDARDS.md
/deslop src/orders                # start with one module you know well
/deslop src                       # then the tree
/deslop repo                      # then everything, directory by directory
/deslop main                      # or just the changes since main
```

`/deslop` runs the existing tests first and adds characterization tests where coverage is thin, then works through eight passes in a fixed order: dead code, comments, abstractions, defensive paranoia, duplication, naming, tests, filler. One category per pass, typecheck and tests after each, revert on red. Behaviour never changes; anything that looks like a bug goes into "Found, not changed". The report shows lines removed per pass, tests before and after, and the inventory tools' counts before and after.

Commit after each pass if you want a reviewable history (`/deslop src --commit` is not a flag; just say "commit each pass" in the same message).

### The compounding loop

When the agent does something you dislike, write one line in `CODING_STANDARDS.md` (created by `/clean-code-setup`). `/clean-code-review` and `clean-code` read it on every run and it overrides the skill's defaults. Date the line; delete it when a linter enforces it. The file stays short, and every mistake happens once.

Full walkthroughs, recipes, CI integration, and troubleshooting: [docs/USAGE.md](docs/USAGE.md).

## Principles

The skill is short because it stands on a small number of load-bearing ideas.

- **Every line earns its place.** A line stays when deleting it loses behaviour or information.
- **Delete over simplify, simplify over optimize, optimize over automate.** The interrogation order, applied before "done". (George Pickett)
- **Deep modules.** A lot of behaviour behind a small interface, placed at a clean seam, tested through that interface. The deletion test decides whether a layer exists. Seams appear at two implementations, not one. (Ousterhout; Matt Pocock's `codebase-design`)
- **Grey box.** A human owns the interface and the tests; the implementation can be delegated or regenerated as long as the tests hold. (Matt Pocock)
- **Match the codebase.** Comment density, naming, and idiom mirror the surrounding code; repo standards override the skill. (Anthropic, Claude Code system prompt, July 2026)
- **Boundaries validate, internals trust.** Validate once at the edge; errors surface; nothing swallows. Define errors out of existence first. (Ousterhout; Anthropic prompting guidance)
- **Comments carry information.** A comment describes what the code cannot: why, invariants, units, ownership. The diagnostic: could a stranger write it from the code alone?
- **Tests earn their place.** A test exists when a plausible bug would make it fail at the public seam. Trivial code, framework behaviour, private internals, and mock-call assertions get none. (Matt Pocock's `tdd`; Simon Willison)
- **Gates over prose.** Tell the agent it has to pass a cyclomatic-complexity lint and it writes simpler code. (Alex Graveley, Ben Vinegar; Mitchell Hashimoto's harness engineering)
- **Evidence before claims.** "Tests pass" means they ran in this session with zero failures, and the report shows the numbers.

## Calibrated for 2026 models

Instruction files accumulate handholding that weaker models needed. In July 2026 Anthropic removed over 80% of Claude Code's system prompt for Claude 5-generation models, replacing rules like "default to writing no comments" with "write code that reads like the surrounding code: match its comment density, naming, and idiom". In September 2026 OpenAI's Codex team told users to strip itinerary-style recipes, blanket "always run tests" nudges, and "ask first" gates from their skills and `AGENTS.md`, and to keep short triggers, progressive disclosure, and explicit completion criteria.

This repo follows that calibration:

- **Kept**: hard gates with a testable standard, a completion criterion for every skill, deterministic lint gates, the report, and the catalog of named flags (naming a flag is what makes a review actionable).
- **Left out**: step-by-step recipes for judgement calls, blanket prohibitions where "match the surrounding code" is enough, "read everything first" mandates, and permission prompts for low-stakes decisions.
- **Still explicitly guarded**: over-engineering, defensive paranoia, unnecessary tests, and scope creep. Anthropic's own prompting guide still documents these as tendencies of current models, and they are exactly the slop that reviewers miss.

Re-audit the skill on each model release: run `/interrogate skills/` in this repo and delete whatever the new model does correctly without being told. `scripts/check.sh` enforces the structural limits (500-line bodies, description length, resolving links, no em dashes).

## Design notes

- Built to Anthropic's skill-authoring guidance: the description is the trigger; the body stays under 500 lines (the core is under 160); everything else is one link deep; scripts do deterministic work so the model does not re-derive it.
- Invocation follows Matt Pocock's split: one model-invoked skill holds the reusable discipline; four user-invoked skills orchestrate and cost zero context until typed.
- `/clean-code-review` runs with `context: fork` so the reviewer has fresh eyes and the working session keeps its context.
- The skills are plain Markdown with the six spec frontmatter fields plus Claude Code's `disable-model-invocation`, `argument-hint`, and `context`; other hosts ignore what they do not know. Each skill ships an `agents/openai.yaml` for Codex's picker.
- Nothing here is language-specific except the lint templates and short "language notes" sections that cover only the shapes agents get wrong.

## Compatibility

| Host | Install | Notes |
|---|---|---|
| Claude Code | skills.sh, plugin, or script | Full support, including `/clean-code-review`'s forked context and the format-on-edit hook. |
| Codex | skills.sh or `scripts/install.sh --codex` | `agents/openai.yaml` supplies picker metadata; user-invoked skills are marked implicit-invocation-off. |
| Cursor, OpenCode, Gemini CLI, Antigravity, others | skills.sh or copy `skills/*` into the host's skills directory | Frontmatter fields the host does not know are ignored. |
| Windows | `scripts/install.ps1` | Skill scripts run under Git Bash. |

## Sources and credits

Built from the sources in [docs/SOURCES.md](docs/SOURCES.md). The largest debts:

- **Matt Pocock** ([mattpocock/skills](https://github.com/mattpocock/skills), [aihero.dev](https://www.aihero.dev)): deep modules, seams and adapters, the `tdd` test discipline, the `code-review` two-axis pattern, `CODING_STANDARDS.md` as the compounding loop, model-invoked vs user-invoked skills, and `writing-great-skills`.
- **John Ousterhout**, *A Philosophy of Software Design*: complexity, deep modules, the red flags, define errors out of existence, comments as a design tool.
- **Anthropic**: skill authoring best practices, Claude Code best practices, the Claude 5 context-engineering post, and the prompting guide's agentic-coding sections.
- **OpenAI Codex DX (Eric Provencher)**: "Rethinking skills and prompts for GPT-6 Astra", September 2026.
- **George Pickett**, **Emanuele Di Pietro**, **Ben Vinegar**, **Alex Graveley**, **Manish Kumar** for the posts that seeded this repo: the interrogation prompt, the repository audit prompt, cyclomatic complexity as a slop fix, and the anti-slop rule tiers.
- **Martin Fowler**, *Refactoring*; **Andrej Karpathy**'s four guidelines; **Jesse Vincent**'s superpowers (`verification-before-completion`); **miqdadbadjuber/anti-slop**; **scanaislop/aislop**; **tmdgusya/engineering-discipline**; **Simon Willison**; **Mitchell Hashimoto**; **Boris Cherny**.

## License

MIT. See [LICENSE](LICENSE).
