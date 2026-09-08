# Security

## What runs on your machine

The skills are Markdown instructions; they do nothing until an agent reads them. Three things in this repo execute:

- `skills/clean-code/scripts/*.sh` and `skills/deslop/scripts/slice.sh`: read-only reporting (`diff-stats.sh`, `complexity.sh`) and the repo-loop bookkeeping (`slice.sh`, which reverts files inside a repo the agent is already editing).
- The hooks `/clean-code-setup` installs into `.claude/hooks/`: they format and lint the file the agent just edited, run the repo's own check command, and block a red `git commit` made by the agent. They run the commands you configured and nothing else; read them before installing, they are short.
- `evals/run.sh`: runs `claude -p` on throwaway copies of the fixtures in a temp directory.

None of them contact a network, read files outside the repository, or store anything but the hook markers in your temp directory.

## Reporting

If you find a way for a crafted repository, prompt, or tool output to make a hook or script do something its comment does not say, email the maintainer at the address in `.claude-plugin/plugin.json` or open a private security advisory on GitHub. Please include the file, the input, and what happened. Expect a reply within a week; fixes ship as a patch release with a changelog entry.

## Scope notes

- The commit gate sees commits the agent makes through its Bash tool. It does not see commits from your shell or from CI, and it is not a substitute for a CI check. Treat it as development feedback; make CI the merge gate.
- `/audit` reports security findings with severity and confidence and fixes only what it can reproduce. It is a review aid, not a penetration test, and it does not replace a security review for code that touches authentication, payments, or secrets.
