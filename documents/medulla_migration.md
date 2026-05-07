---
title: Medulla Migration & Fork Plan
date: 2026-05-01
author: Claude (Opus 4.7), in dialogue with Ben
status: SUPERSEDED — see beads_migration.md
superseded_reason: Decision shifted to gastownhall/beads (active upstream, multi-agent primitives built-in). The Medulla fork at github.com/bhougland18/medulla is preserved but unused; delete or keep at your discretion.
relates_to:
  - upstream: https://github.com/skeletor-js/medulla (archived 2026-04-26)
  - replaces: beads_rust (`br` CLI, currently used in stac-forui-components/.beads/)
  - devshell-source: ~/nix-config/devshells/features/
---

> **This document is historical.** After researching `gastownhall/beads`,
> we decided that's the better fit for the multi-agent task delegation
> use case. See `beads_migration.md` for the active plan. Sections below
> are kept for context only.

---

# Medulla Migration & Fork Plan

## 1. Context

You want to switch project task / context tracking from **beads_rust**
(currently in `~/code/stac-forui-components/.beads/`, ~39 issues) to
**Medulla**. Medulla provides materially more than a task DB: it's a
"git-native knowledge engine" with tasks + decisions + prompts, MCP
server built-in, CRDT-based storage, and semantic search.

Complication: **upstream Medulla was archived on 2026-04-26**, so the
migration is also a fork. The fork is yours to maintain going forward
— upstream is read-only.

The CRDT angle is non-trivial: Medulla's storage layer is Loro CRDT,
which is the same conceptual layer ZeroFlat will use for state sync.
Owning a fork that uses Loro gives you a working integration to
reference when ZeroFlat's CRDT/RDF design session lands.

---

## 2. Snapshot: Medulla vs. beads_rust

### 2.1 What you'd gain

| Capability | beads_rust | Medulla |
|---|---|---|
| Tasks | ✓ | ✓ |
| Decisions (with context / consequences) | — | ✓ first-class entity |
| Prompts (parameterized templates) | — | ✓ |
| MCP server (Claude Code, Gemini, Cursor) | — | ✓ stdio + HTTP |
| Semantic search (embeddings) | — | ✓ via fastembed |
| Full-text search | partial (regex) | ✓ SQLite FTS |
| CRDT sync (cross-device, multi-agent) | — | ✓ Loro CRDT |
| Auto-generated markdown snapshots | — | ✓ |
| Issue dependencies (parent-child, blocks) | ✓ | partial (graph ops) |
| JSONL export | ✓ | (markdown snapshot only) |
| Conformance with a Go original | ✓ | n/a |
| Self-update from GitHub releases | ✓ | partial |

### 2.2 What you'd lose / new ownership cost

- **Upstream maintenance.** Medulla is archived; security patches,
  Rust toolchain bumps, and Loro/MCP version updates are now your job.
- **Active community.** No issue tracker, no PRs, no discussion. You
  fork into silence.
- **Conformance discipline.** beads_rust tests parity with a Go
  original. Medulla has no analogous reference; the test suite is the
  only source of truth.
- **Binary CRDT storage in git.** `.medulla/loro.db` is a binary blob
  in the repo. Diffs are opaque; merge conflicts on the blob require
  Medulla to resolve. The auto-snapshot markdown gives you a
  human-readable view, but that's a *projection*, not the diff.

### 2.3 Existing beads data to migrate

`~/code/stac-forui-components/.beads/` holds:

- `beads.db` (SQLite, ~292 KB)
- `issues.jsonl` (39 issues, ~26 KB) — most are closed
- `metadata.json`, `config.yaml`
- `.br_history/` (history snapshots)

The JSONL is the canonical migration source. A representative entry:

```jsonc
{
  "id": "stac-forui-components-1ci",
  "title": "Implement FCard model and parser",
  "status": "closed",
  "priority": 2,
  "issue_type": "task",
  "labels": ["presentation"],
  "dependencies": [{"depends_on_id": "stac-forui-components-8xr",
                    "type": "parent-child"}],
  "close_reason": "Implemented StacForuiCard model and parser ...",
  ...
}
```

Mappable to Medulla's task entity, with:

- `id` → Medulla entity id (kept verbatim if format allows; otherwise
  prefixed/normalized).
- `labels[]` → Medulla tags / categories.
- `dependencies[]` → Medulla graph edges. Parent-child maps to
  Medulla's hierarchical task relation if it has one; otherwise to a
  generic `blocks` / `relates_to` edge.
- `close_reason` → Medulla task closure note (need to confirm field).

---

## 3. Open decisions (please answer before we cut the fork)

### Q1. Fork name and hosting

- **Repo name.** Keep `medulla`? Use `medulla-rs`? `medulla-hb` (your
  initials/branding)? Naming affects downstream — npm package, brew
  formula, MCP server binary name.
- **GitHub org/user.** Your personal account, or a new org?
- **Visibility.** Public (apache-2.0 already permits) or private?
  Public preserves the Apache-2.0 lineage and lets you accept PRs
  later if anyone else cares; private is simpler to start.

### Q2. Scope of fork

Three reasonable postures, ordered by ambition:

- **Caretaker fork.** Build it, fix what breaks, no new features.
  Replaces beads_rust, nothing more. Lowest cost.
- **Active fork.** Caretaker + targeted improvements you actually need
  (e.g., better task-dependency model, ZeroFlat-specific MCP tools).
  Medium cost.
- **Strategic fork.** Active + new directions (e.g., RDF backend
  alongside Loro, ZK integration, multi-tenant). Probably premature —
  re-evaluate after ZeroFlat ships.

I'd recommend **caretaker for v1**, promote to active only when a
real itch appears.

### Q3. Beads data migration scope

- Migrate the **39 issues from stac-forui-components**? Most are
  closed; you may not care about historical task data once Gemini
  takes over that repo.
- Or **fresh start**: archive `.beads/` as-is, start Medulla empty in
  zeroflat (and any other active repo).
- Are there **other repos with beads data** I should know about? I
  saw `~/code/conduit/` exists — does it have a `.beads/` directory?

### Q4. MCP wiring

- Medulla speaks MCP (stdio + HTTP). It needs to be registered with
  Claude Code (and probably Gemini for the parallel work in
  stac-forui-components).
- Per-repo (each repo gets its own Medulla instance + MCP server) or
  single global instance with per-repo namespaces? Per-repo matches
  Medulla's design (`.medulla/` is repo-scoped); global would require
  more thought.
- Should the MCP server auto-start with `direnv` on entering a
  Medulla-enabled repo, or be on-demand?

### Q5. Loro CRDT in git — comfortable?

The `.medulla/loro.db` binary in git is a meaningful tradeoff:

- **Pro:** Conflict-free across branches and devices; the snapshot
  markdown gives you human-readable history.
- **Con:** Opaque diffs, larger git footprint over time, no `grep` on
  the raw store. You'd be looking at the markdown snapshot when you
  want to read history, not at git log.

If this is uncomfortable, beads_rust's text-based JSONL is more
inspectable — but that's the tradeoff you're choosing to make for
MCP + decisions + sync.

---

## 4. Fork plan (assuming Q1–Q2 pick: public repo on your account, caretaker scope)

### 4.1 Mechanics

1. **Pre-fork inventory.** `gh api repos/skeletor-js/medulla` to capture:
   - Default branch HEAD commit at archive time.
   - Open issues and PRs at archive (none active, but worth recording).
   - Releases and version history (npm/homebrew packages, what's
     pinned to what).
2. **Fork via GitHub.** Cleanest path is `gh repo fork
   skeletor-js/medulla` — keeps the lineage explicit, lets you pull
   any future un-archive or community fork, gets the apache-2.0
   notice right by default.
3. **Update repo metadata** post-fork:
   - Description: note the fork rationale + maintenance posture.
   - README banner: "Maintained fork of skeletor-js/medulla
     (archived 2026-04-26)."
   - Topics: keep `mcp`, `crdt`, `knowledge-engine`; add
     `personal-fork` to signal scope.
4. **Add `FORK.md`** at repo root: one-page doc covering fork
   rationale, maintenance scope, deviation policy, upstream tag
   (commit sha at fork point).
5. **Local clone** at `~/code/medulla/`.

### 4.2 First-pass verification (before any feature work)

Run the upstream test suite as-is. If any of these fail, that's the
first work to do (and a signal about how much rot was in the
codebase at archive time):

- `cargo check --all-targets`
- `cargo test`
- `cargo clippy --all-targets -- -D warnings`
- `cargo fmt --check`
- Build the MCP server binary, register it with Claude Code locally,
  call `medulla list` via MCP, confirm the response.

If everything's green, the fork is in good shape. If most things
fail, we have a sense of the "caretaker" workload.

### 4.3 What I'd patch immediately

These are speculative until I read the codebase, but typical for an
archived Rust project:

- Bump Rust edition / toolchain to whatever your other Rust projects
  use. The user-shared `rust-toolchain.toml` patterns from beads_rust
  (Rust 2024, nightly) might not match Medulla's pin.
- Bump `serde`, `tokio`, `clap`, MCP-protocol crate to current
  versions if any are stale.
- Re-enable CI on the fork (GitHub Actions workflows are inherited
  but typically need the fork's secrets/permissions).
- Add `Cargo.lock` to `.gitignore`-or-not per your preference for
  CLI binaries (usually committed for binaries, ignored for libs;
  Medulla is a binary).

---

## 5. Devshell / `flake.nix` design

Reusing your `~/nix-config/devshells/features/` modules. From what's
available there, the relevant features for a Rust+MCP project:

| Feature | Purpose |
|---|---|
| `core.nix` | Baseline POSIX tools |
| `direnv.nix` | Auto-activate the shell on `cd` |
| `native-cc.nix` | C toolchain (likely needed for SQLite, fastembed) |
| `rust.nix` | Rust toolchain |
| `rust-devtools.nix` | rust-analyzer, cargo-watch, etc. |
| `rust-lint-dylint.nix` | Lint runners |
| `crane.nix` | (Optional) Nix-native Rust builds for reproducibility |
| `jujutsu.nix` | VCS, if you use jj alongside git here |
| `ai-tools.nix` | If you want Claude Code / agents in-shell |

Sketch of `flake.nix`:

```nix
{
  description = "Medulla — personal fork of skeletor-js/medulla";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-config = {
      url = "path:/home/ben/nix-config";  # or a git url if you want pinning
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, nix-config, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        features = nix-config.lib.devshells.features;
      in {
        devShells.default = pkgs.mkShell {
          inputsFrom = with features; [
            core
            direnv
            native-cc
            rust
            rust-devtools
            rust-lint-dylint
            crane
            jujutsu
          ];
          shellHook = ''
            echo "medulla devshell — fork of skeletor-js/medulla"
          '';
        };
      });
}
```

(The exact `nix-config.lib.devshells.features` path depends on how
your nix-config exposes the feature modules — I haven't read the
flake there. The structure of the call site is right; the binding
expression may need tweaking.)

Two nix-side decisions:

- **Flake input pinning for `nix-config`.** Path-based input means
  the medulla shell tracks your local edits to nix-config — convenient
  for iteration, less reproducible. Switch to a git url before any
  CI uses the flake.
- **Crane vs. plain `cargo build`.** Crane gives Nix-native caching
  and reproducible builds, useful if you want the medulla binary
  available as a Nix package consumed by other projects' shells (a
  natural fit alongside your `beads.nix` feature). Skip crane if
  you only ever `cargo install` it.

The `~/nix-config/devshells/features/beads.nix` feature presumably
installs the `br` binary into the shell. We'd add a parallel
`medulla.nix` once the fork builds reproducibly — that's how other
projects (zeroflat, conduit, future repos) consume the fork.

---

## 6. Data migration (beads JSONL → Medulla)

### 6.1 Field mapping

| beads field | Medulla equivalent | Notes |
|---|---|---|
| `id` (e.g., `stac-forui-components-1ci`) | task `id` | Keep verbatim if Medulla allows arbitrary ids; otherwise normalize and store original in a `legacy_id` field |
| `title` | `title` | 1:1 |
| `description` | `description` / body | 1:1 |
| `status` (`open`/`closed`/...) | task status | Confirm Medulla's status vocabulary |
| `priority` (int) | task priority | 1:1 if same scale; otherwise map |
| `issue_type` (`task`/`bug`/...) | entity type / tag | Tasks → tasks; bugs probably → tasks tagged `bug` |
| `labels[]` | tags | 1:1 |
| `dependencies[]` (parent-child) | graph edges | Need to confirm Medulla's edge model |
| `close_reason` | closure note | Confirm field |
| `created_at`, `updated_at`, `closed_at` | timestamps | 1:1 |
| `created_by` | author | 1:1 |
| `source_repo` | repo metadata | Probably implicit (repo-scoped Medulla) |
| `compaction_level`, `original_size` | — | beads-internal; drop |

### 6.2 Migration path

Three options:

- **Option A — Manual import via Medulla CLI.** Loop through JSONL,
  call `medulla add task ...` for each. Slow but visible; easy to
  fix issues mid-flight.
- **Option B — Write a `br-to-medulla` converter.** A small Rust
  tool (or shell + jq) that reads beads JSONL, emits Medulla import
  format. Worth it if more than one repo's worth of beads data
  needs migration.
- **Option C — Skip migration.** Archive `.beads/` per-repo, start
  Medulla fresh. Lowest-effort; loses historical task context. For
  stac-forui-components specifically, most issues are closed; the
  loss is small.

My recommendation depends on Q3. For the 39-issue
stac-forui-components case alone, **Option C** is probably right.
If conduit (or any other repo) also has a meaningful beads history,
**Option B** earns its keep.

### 6.3 Per-repo migration sequence

In whatever order:

1. **stac-forui-components** — Gemini owns this; if migrating, do it
   *before* handoff so Gemini inherits Medulla, not beads. If
   skipping migration, freeze `.beads/` as the historical record.
2. **zeroflat** — fresh start. Initialize Medulla on day one. This is
   the easiest and most useful target for the new tooling.
3. **conduit** — TBD pending Q3 (does it have beads data?).
4. **future repos** — Medulla by default via the new
   `~/nix-config/devshells/features/medulla.nix`.

---

## 7. MCP wiring

### 7.1 Claude Code

Once the binary builds, register the MCP server:

```bash
# Per-project (preferred, matches Medulla's repo-scoped design):
cd ~/code/zeroflat
claude mcp add medulla --scope project -- medulla serve --stdio

# Or globally for all projects:
claude mcp add medulla --scope user -- medulla serve --stdio
```

(Exact command shape depends on Medulla's `serve` flags — verified
post-fork.)

### 7.2 Gemini (for stac-forui-components)

Gemini's MCP support is configured via its own settings file (path
varies by integration). Same binary, same `serve --stdio` invocation;
the Medulla server is client-agnostic.

### 7.3 What the agent gets

Medulla exposes (per the upstream README):

- Entity CRUD over MCP tools (create / update / search tasks,
  decisions, prompts).
- Semantic + FTS search over the corpus.
- URI-style resources (`medulla://decisions`, `medulla://tasks/active`).

This means Claude (or Gemini) can, mid-conversation:
- "List open tasks tagged `theming`" → MCP query.
- "Record a decision: we chose tokens over hex" → MCP write.
- "What did we decide about the delta protocol?" → semantic search.

Worth noting: this overlaps with my auto-memory system. Both store
project state. The split I'd suggest:
- **Memory** for cross-session preferences, user profile, feedback
  rules — things scoped to "how Claude works with Ben."
- **Medulla** for project-scoped knowledge — tasks, architectural
  decisions, prompts that any agent on the project should consult.

---

## 8. Sequencing

Strawman, in order. None of these blocks ZeroFlat's components.md
work or stac-forui-components' completion under Gemini.

### Phase 0 — Decide (this week)

- Answer Q1–Q5 (§3).
- Fetch upstream Medulla source locally; skim it. ~30 min, gives a
  ground truth for "caretaker workload."

### Phase 1 — Cut the fork (1–2 days)

- Fork on GitHub, clone to `~/code/medulla/`.
- Run §4.2 verification (build, test, clippy, MCP smoke test).
- Add `FORK.md`, update README banner.
- Triage what broke. Fix or open self-issues for each.

### Phase 2 — Devshell (1 day)

- Write `flake.nix` (§5 sketch).
- Add `~/nix-config/devshells/features/medulla.nix` exposing the
  built binary as a Nix package.
- Test from a fresh `direnv allow` in a scratch repo.

### Phase 3 — First adoption (1–2 days)

- Initialize Medulla in `~/code/zeroflat/` (no migration needed).
- Register the MCP server with Claude Code.
- Convert the existing zeroflat docs (initial proposal, evaluation,
  components.md, this plan) into Medulla decisions / prompts where
  appropriate. Keep the markdown originals; Medulla is additive.
- Use it for a week of real work. See what breaks, what's missing.

### Phase 4 — Migration of existing repos (1–3 days, depends on Q3)

- Per-repo per the §6.3 sequence.

### Phase 5 — Maintenance posture (ongoing)

- Pin a cadence (monthly?) for: dependency updates, Rust toolchain
  bumps, MCP protocol version checks.
- Watch for community forks of medulla; if one emerges and is well-
  maintained, consider rebasing your fork onto it.

---

## 9. Risks & long-term ownership

- **You now own the codebase.** Estimate 4–8 hours/month of caretaker
  time (toolchain bumps, dep updates, occasional bug fixes), more if
  Loro or MCP introduce breaking changes. Cheap, but not zero.
- **Loro is also in flux.** Loro CRDT is itself relatively new; major
  version changes could require migration logic in your fork.
  Worth pinning Loro and bumping deliberately, not chasing latest.
- **MCP protocol churn.** Anthropic's MCP spec evolves; an old
  Medulla against a new MCP client could fail silently. Smoke-test
  the MCP path on every Claude Code update.
- **Sole-maintainer risk.** If you stop maintaining the fork, you're
  back to "archived but with your name on it." Worth periodically
  asking: "is this still the right tool, or has something better
  emerged?" — sunset criteria help.
- **Apache-2.0 license preservation.** Keep the upstream LICENSE,
  NOTICE, and any SPDX headers intact. The fork notice in FORK.md
  satisfies the attribution requirement explicitly.

---

## 10. Bottom line + immediate next steps

- Medulla is meaningfully more capable than beads_rust (MCP,
  decisions, semantic search, CRDT). The fork tax is real but small
  if scoped to caretaker.
- The CRDT storage is incidentally a working reference for ZeroFlat's
  upcoming CRDT design — bonus value beyond just task tracking.
- Plan needs Q1–Q5 (§3) answered before I can act. The high-leverage
  ones are Q1 (name/host) and Q3 (migration scope).

When you're ready:

1. Answer §3 questions.
2. I'll do the §4.2 verification on the fork once it exists (I can't
   create the GitHub fork myself — you need to run `gh repo fork
   skeletor-js/medulla` or click "Fork").
3. Then Phase 2 (devshell) and Phase 3 (zeroflat adoption) in
   sequence.
