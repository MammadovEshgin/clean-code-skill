# Coding Standards

Rules for this repo that differ from the `clean-code` skill's defaults, plus rules that came from real mistakes. Where this file is silent, the skill applies. Every line here is loaded into every review, so keep it short and delete lines once tooling enforces them.

## Stack

- Language and runtime:
- Formatter: (runs automatically; never hand-format)
- Linter: (complexity 10, depth 3, params 4; see the config)
- Typecheck:
- Tests:
- Check everything: `<check command>` (run before calling any change done)

## Conventions that differ from the skill

<!-- Only genuine differences. Examples: -->
- Comments: exported API gets a one-line doc comment; internal code has none unless something is non-obvious.
- Errors: HTTP handlers return a typed error response; nothing throws across the handler boundary.

## Layout

<!-- One paragraph: where modules live, what counts as an entry point, where tests go. -->

## Ratchets

<!-- Thresholds temporarily above the skill's budget, with the target. Delete the line when the target is reached. -->
- complexity: currently 14 in `src/legacy/parser.ts`; target 10.

## Rules from mistakes

<!-- Each line exists because an agent or a human did the opposite once. Date it. Delete it when a linter enforces it. -->
- 2026-09-07: Import module entry points directly; no barrel `index.ts` re-exporting subtrees.
