# Structure

How to shape modules, files, and projects so that humans and agents can navigate them. The organizing idea is the **deep module**: a lot of behaviour behind a small interface.

## Contents

- Deep modules
- Module layout
- Project layout
- Dependency direction
- What not to create
- Configuration
- New project checklist
- Language notes

## Deep modules

```
Deep (aim for this)              Shallow (avoid)
┌──────────────────┐             ┌──────────────────────────────┐
│  small interface │             │       large interface         │
├──────────────────┤             ├──────────────────────────────┤
│                  │             │  thin implementation          │
│  deep            │             └──────────────────────────────┘
│  implementation  │
│                  │
└──────────────────┘
```

- **Depth is leverage**: how much behaviour a caller or test gets per unit of interface learned.
- **Depth is a property of the interface.** A deep module may be built from small internal parts; they are just not part of the interface.
- **The interface is the test surface.** Tests and callers cross the same seam. Testing past it means the module is the wrong shape.
- **Deletion test**: delete the module in imagination. Complexity vanishes: it was a pass-through. Complexity reappears across callers: it earned its keep.
- **Seams appear at two.** One implementation is a hypothetical seam; introduce the interface when the second adapter (a real one or a test fake) exists.
- **Grey box**: a human owns the interface and the tests; the implementation inside can be delegated, rewritten, or regenerated as long as the tests hold.

Questions to ask of any interface: fewer methods? simpler parameters? more hidden inside?

## Module layout

A module gets a folder. Its public surface is the files at the folder root; everything in subfolders is private.

```
src/
  billing/                ← module
    index.ts              ← entry point (public)
    client.ts             ← another entry point, if the module has two audiences
    lib/                  ← implementation, private
      invoice.ts
      tax.ts
    tests/                ← tests, importing only through ../index
      billing.test.ts
```

- Outsiders import entry points only. A deep import into `lib/` is a boundary violation.
- Several small entry points beat one barrel that re-exports the whole tree.
- Tests live with the module they test (or in the repo's existing test tree if it has one; follow the repo).
- A module may nest internals as deep as it likes. A module does not contain another module.

Enforce the boundary with tooling when the language allows it (dependency-cruiser or ESLint `no-restricted-imports` for TypeScript, `internal/` packages in Go, `pub(crate)` in Rust, `__all__` plus an import linter in Python).

## Project layout

Organize by **domain** (what the code is about), then by kind within a domain. Technical-layer top levels (`controllers/`, `services/`, `models/`, `utils/`) scatter one feature across the tree and force every change into shotgun surgery.

```
src/
  orders/                 ← domain module
  payments/               ← domain module
  identity/               ← domain module
  platform/               ← shared infrastructure the domains depend on (db, http, config)
  app.ts                  ← composition root: wires modules together
```

- Each domain module owns its types, logic, persistence adapter, and tests.
- `platform/` (or `infra/`, `core/`) holds genuinely shared mechanisms. It is not a dumping ground; each thing in it has two or more domain users.
- The composition root is the one place that knows about everything. Nothing imports it.
- Frameworks with a mandated layout (Next.js `app/`, Django apps, Rails) keep their convention; apply domain grouping inside it.

## Dependency direction

Imports point inward, toward the code with the fewest reasons to change.

```
adapters (http handlers, db, cli, external APIs)
        ↓ may import
application (use cases, orchestration)
        ↓ may import
domain (types, rules, pure logic)
```

- Domain code imports nothing from adapters or frameworks.
- Adapters depend on domain interfaces; domain code never names a concrete adapter.
- Cycles are a design error. Break them by moving the shared piece downward or merging the two modules.
- Keep the number of layers to what the deletion test justifies. A three-layer split where the middle only forwards is two layers with a middle man.

## What not to create

- `utils/`, `helpers/`, `common/`, `misc/`, `shared/` folders that collect unrelated functions. Put each function beside its user or inside the module that owns the concept.
- `base` classes, abstract classes, or interfaces with one implementation.
- A monorepo, package split, or microservice boundary before two independent deployables exist.
- Barrel files that re-export whole subtrees.
- Wrapper modules around a library that only rename its functions.
- A `types/` folder holding types away from the code that uses them. Types live with their module; only genuinely shared domain types move to the domain root.
- Config layers, plugin systems, or dependency-injection containers for a codebase with one configuration.
- Generated scaffolding kept "just in case": sample handlers, example tests, default README text.

## Configuration

- One typed config object, read and validated once at startup, passed down explicitly. No `process.env` or `os.environ` reads scattered through the code.
- Fail at startup on a missing or malformed value, with the name of the value in the message.
- Compute a value inside the code when the code knows better than the operator. Expose a knob only when a user genuinely has better information.
- Secrets never appear in code, defaults, or logs.

## New project checklist

When creating a project from nothing:

1. Identify the two or three domain modules the first feature needs. Create only those.
2. Give each a folder with an entry point, a `lib/` (or the language's equivalent), and a test file that imports through the entry point.
3. Add a composition root.
4. Add the toolchain in this order: formatter, linter with complexity gates (`/clean-code-setup`), typecheck, test runner, one `check` script that runs all four.
5. Write `CODING_STANDARDS.md` with the three or four decisions that differ from defaults. Point `CLAUDE.md` or `AGENTS.md` at it.
6. Stop. Add structure when the second caller, second adapter, or second deployable appears.

## Language notes

Only the shapes agents commonly get wrong. Repo convention wins over any line here.

**TypeScript / JavaScript**
- Named exports; default exports only where the framework requires them.
- No barrel re-exports of subtrees. Entry points export a curated surface.
- Discriminated unions for state; `readonly` where mutation is not intended.
- `unknown` at boundaries, narrowed once; `any` never without a reason.
- ES modules, `import type` for types, no circular imports.

**Python**
- One package per domain module with `__init__.py` exposing the public surface via `__all__`.
- `dataclass` (frozen where possible) or Pydantic at boundaries for shapes; plain functions over classes with one method.
- Type hints on public signatures; `pathlib` over string paths; no mutable default arguments.
- Exceptions are specific classes; `except Exception` only at the top-level boundary.

**Go**
- Small packages named for what they provide (`billing`, not `billingutils`); `internal/` for private packages.
- Accept interfaces, return structs; define the interface where it is consumed, with the one or two methods actually used.
- Errors wrapped with `%w` and context; no panics in library code; `context.Context` first parameter.
- No `pkg/` or `utils/` dumping grounds.

**Rust**
- Modules mirror the domain; `pub(crate)` by default, `pub` only for the crate's surface.
- Newtypes for identifiers and units; enums for state; `Result` with a crate error type (`thiserror`) in libraries, `anyhow` in binaries.
- `unwrap`/`expect` only in tests and with a stated invariant.
- Traits at seams with two implementations; generics where monomorphization pays, `dyn` where it does not.
