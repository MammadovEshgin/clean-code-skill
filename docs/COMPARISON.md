# How it compares

An honest comparison against the skills and tools people actually install for code quality, as of September 2026. Star counts are from GitHub on 2026-09-07. Every row was read in full, not summarized from a listing.

## Contents

- The matrix
- What each alternative does best
- Where this repo is weaker
- Verdict

## The matrix

Columns are the layers a slop solution needs. A filled circle means the layer is a first-class, tested part of the package; a half circle means partial or indirect; a dash means absent by design.

| | Writes without slop (auto-loads) | Cleans existing code, behaviour locked | Deterministic gates | Fresh-context review | Report with numbers | Tests-slop rules | Structure / deep modules | Languages | Size, 2026 calibration |
|---|---|---|---|---|---|---|---|---|---|
| **clean-code-skill** (this repo) | ● | ● 9 ordered passes | ● installs lint gates; integrates aislop and anti-slop | ● forked context | ● diff, complexity, erosion | ● gate + decision list | ● | any (rules); TS/JS, Py, Go, Rust (gates) | 156-line core, one link deep |
| Claude Code `/simplify` + `/code-review` (built in) | ◐ system prompt only | ◐ changed code, no lock ritual | – | ● | – | – | – | any | n/a |
| [mattpocock/skills](https://github.com/mattpocock/skills) 255k★ | ◐ via `tdd`, `codebase-design` | – | – | ◐ two-axis review in sub-agents | – | ● `tdd` | ● best vocabulary available | any | small skills, process-first |
| [obra/superpowers](https://github.com/obra/superpowers) 282k★ | ◐ methodology | – | – | ◐ `requesting-code-review` | – | ◐ TDD | – | any | medium |
| [Karpathy CLAUDE.md](https://github.com/multica-ai/andrej-karpathy-skills) 210k★ | ● 4 principles | – | – | – | – | – | – | any | 60 lines |
| [dmmulroy/anti-slop](https://github.com/dmmulroy/anti-slop) 4.1k★ | – | – | ● 15 Oxlint rules, type evidence | – | – | ◐ `no-module-mocking` | – | TS/JS | vendored code |
| [Dimillian review-and-simplify](https://github.com/Dimillian/Skills) 3.9k★ | – | ◐ safe fixes on changed code | – | ● read-only sub-agents | – | – | – | any | 185 lines |
| [wondelai clean-code](https://github.com/wondelai/skills) 2.1k★ | ◐ on trigger phrases | – | – | – | ◐ 0-10 score | ◐ | – | any | 222 lines |
| [miqdadbadjuber/anti-slop](https://github.com/miqdadbadjuber/anti-slop) 1.4k★ | ◐ UI, copy, comments | ◐ audit mode | – | – | ◐ delivery gate | – | – | any | 38 rules + skills |
| [scanaislop/aislop](https://github.com/scanaislop/aislop) 599★ | – | ◐ mechanical fixes | ● 50+ rules, score, CI | – | ● score | – | – | 10 | tool, not a skill |
| [ertugrul-dmr/clean-code-skills](https://github.com/ertugrul-dmr/clean-code-skills) 177★ | ● per language | – | – | – | – | ◐ opposite stance on trivial tests | – | TS, Py | 7 skills per language |
| [tmdgusya clean-ai-slop](https://github.com/tmdgusya/engineering-discipline) 126★ | – | ● 6 passes, behaviour locked | – | – | – | – | – | any | one skill |
| [PaulRBerg code-polish](https://github.com/PaulRBerg/agent-skills) 70★ | – | ◐ high-confidence simplifications | – | ◐ risk profiles | – | – | – | any | 96 lines |
| [btseee/clean-code-skills](https://github.com/btseee/clean-code-skills) 10★ | ◐ | ◐ audit ledger | – | – | – | ◐ | ● Clean Architecture | any | 500-line router + references |

## What each alternative does best

**Claude Code built-ins.** `/simplify` fans out parallel agents over reuse, simplification, efficiency, altitude, and conventions, then applies fixes; `/code-review` verifies findings before reporting. They are excellent for the diff in front of you. They do not lock behaviour before cleaning, do not touch tooling, and do not report numbers. The system prompt's "match the surrounding code" is the same default this repo adopts.

**mattpocock/skills.** The most complete engineering process available as skills: grilling, specs, tickets, TDD at agreed seams, two-axis review, domain modelling, architecture deepening. It is process-first rather than slop-first, and it is the source of this repo's module vocabulary and test rules. Use both: Matt's for the workflow, this repo for the code that comes out of it.

**obra/superpowers.** A methodology (brainstorm, plan, TDD, review, verify). `verification-before-completion` is the best statement of "evidence before claims" anywhere; this repo's gate is modelled on it.

**Karpathy's CLAUDE.md.** Four principles in sixty lines, always on. The right nano layer; it has no cleanup, no gates, and nothing about tests.

**dmmulroy/anti-slop.** The sharpest deterministic take on TypeScript slop: a type is a claim backed by evidence, and the rules reject every way of fabricating it (widen then assert, chained casts, `unknown` in signatures, `typeof` narrowing away from the boundary, module mocking). TypeScript only, Oxlint only, vendored. This repo adopted the evidence framing in its rules and offers to vendor the plugin from `/clean-code-setup`.

**scanaislop/aislop.** A deterministic scanner: 50+ rules across ten languages, a 0-100 score, CI gating on changed files, a Claude Code hook. It finds what a regex can find and nothing that needs judgement. This repo calls it from `/deslop` when present and recommends it as the CI gate.

**Dimillian, PaulRBerg.** Careful, Codex-friendly review-and-simplify flows with read-only sub-agents, explicit scope resolution, and risk-ranked findings. Neither has a slop catalog, gates, or a before/after report.

**wondelai, ertugrul-dmr, btseee.** Robert C. Martin's *Clean Code* as skills, with worked examples. Valuable as teaching material. They are long, they predate the 2026 guidance on instruction size, and ertugrul-dmr's "do not skip trivial tests" is the opposite of the bet this repo makes.

**tmdgusya clean-ai-slop.** The closest ancestor of `/deslop`: lock behaviour, one smell per pass, verify after each. This repo adds the tooling inventory, three more passes (naming, filler, complexity hotspots), the report, the setup that makes the gates permanent, and the `repo` mode that plans a whole codebase into slices and lands each as its own commit from a fresh context.

## Where this repo is weaker

- **No scanner of its own.** Deterministic detection is delegated to the linters, aislop, and anti-slop. That is a design choice (the linters are better maintained than a regex list in a skill), but it means a repo with no tooling gets judgement-only cleanup until `/clean-code-setup` runs.
- **Small evidence base.** Two evals fixtures and one live run. The alternatives with six-figure stars have thousands of hours of use behind them. The evals harness exists so the number can grow.
- **No process layer.** Nothing here plans, writes specs, or drives TDD. Pair it with mattpocock/skills or superpowers.
- **Prose gates are still prose.** Seven hard gates in a Markdown file bind a model as much as any instruction does. The lint gates and the report exist because of that limit, not in spite of it.

## Verdict

No other package covers all the layers: prevention that loads itself, cleanup that locks behaviour, gates that insist, review with fresh eyes, tests treated as slop when they cannot fail, structure guidance, and a numbers report, in a form sized for 2026 models. The individual layers have stronger specialists (aislop for scanning, dmmulroy for TypeScript type evidence, Matt Pocock for architecture and process), and this repo integrates or credits each rather than re-implementing them.

Whether it is *more effective* is a question the evals answer, not this document. Run `evals/run.sh`, add a fixture from your own codebase, and compare.
