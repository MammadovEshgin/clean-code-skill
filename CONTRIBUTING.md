# Contributing

Thank you for looking at the skills closely. Changes are welcome when they make the skills more effective, more honest, or cheaper to run, and when they come with the evidence that shows it.

## Before you open a pull request

1. Run `bash scripts/check.sh`. It validates every skill against the Agent Skills limits, this repo's own rules (no em dashes, links resolve, `plugin.json` lists every skill), parses every shell and JSON file, and runs the hook and slice tests.
2. If you changed a skill's behaviour, run the fixtures it affects: `bash evals/run.sh <fixture>`. Each run costs real tokens and a few minutes. Paste the result line into the pull request; the runner also appends it to `evals/results/log.tsv` with the Claude Code version.
3. If you changed a rule, name the source. Every rule in this repo traces to a post, a book, a tool, or a real failure listed in `docs/SOURCES.md`; a rule without a source is an opinion, and opinions go in `CODING_STANDARDS.md` of the repos that hold them.
4. Keep the size discipline. `SKILL.md` bodies stay under 500 lines and, more importantly, under the token counts in the README's budget table. Add to a reference file, not to the core, and add a section-map entry so the new material is loaded only when needed.

## What a good change looks like

- A gate or rule phrased as the contract it protects, not as a banned pattern.
- A script for anything stateful (hooks, the repo loop), with a test beside it in `scripts/`.
- A fixture in `evals/fixtures/` whose `check.sh` can fail for the failure you are preventing, plus a `baseline` prompt so the no-skill arm can run.
- Docs that say what is implemented, what is tested, and what is only intended.

## Reporting a problem

Open an issue with the skill name, the host (Claude Code, Codex, Cursor, other), the operating system, the version (`git describe --tags`), the prompt, and what happened. For a security problem in the hooks or scripts, see `SECURITY.md`.

## Style

Plain sentences, no em dashes, no emoji, no marketing. Commit messages explain the why; the first line is conventional (`feat:`, `fix:`, `docs:`, `refactor:`).
