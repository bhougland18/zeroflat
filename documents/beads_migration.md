---
title: Beads (gastownhall/beads) Adoption Plan
date: 2026-05-01
author: Claude (Opus 4.7), in dialogue with Ben
status: Active plan — supersedes medulla_migration.md
upstream: https://github.com/gastownhall/beads
replaces: beads_rust (`br` CLI in stac-forui-components/.beads/)
related: medulla_migration.md (historical)
devshell-source: ~/nix-config/devshells/features/
---

# Beads Adoption Plan

## 1. Decision summary

Switching from beads_rust to **gastownhall/beads** (Go, Dolt-backed,
actively maintained). Rejected: forking archived Medulla and building
multi-agent primitives ourselves.

Reasons in one paragraph: the requirement that surfaced — *tag tasks
by agent tier and let lower-tier agents pick them up safely* — maps
directly onto features `gastownhall/beads` already ships (`bd ready`,
`bd update <id> --claim`, hash-based merge-safe IDs, hierarchical
epics). Active upstream means no caretaker tax. We trade Medulla's
nicer entity model (decisions, prompts, semantic search) for working
multi-agent primitives and zero maintenance burden. Decisions/ADRs
live as markdown in `docs/adr/` per repo, queryable by grep or by an
agent walking the file tree.

The Medulla fork at `github.com/bhougland18/medulla` is preserved
unused. Delete at your discretion.

## 2. What we're keeping from the prior plan

- **Per-project scope.** Each repo gets its own `.beads/` directory
  and its own MCP server. (Q4 from the Medulla plan.)
- **Skip historical migration.** The 39 issues in
  `stac-forui-components/.beads/` stay frozen as-is — Gemini works
  there with beads_rust, the historical record stays intact. (Q3.)
- **Caretaker posture.** No fork; just consume upstream. (Q2 trivially
  satisfied.)
- **Devshell integration via `~/nix-config/devshells/features/`.**
  Existing `beads.nix` gets rewritten to consume gastownhall/beads's
  flake input.

## 3. Mental model: the Beads / JJ split

```
┌─────────────────────────┐                ┌──────────────────────────┐
│ Beads (.beads/)         │                │ JJ (code)                │
│  - Epics                │                │  - Each commit references│
│  - Tasks                │ ◄── id ref ──► │    a bead id in its      │
│  - Dependency graph     │                │    description           │
│  - ADRs (in docs/adr/)  │                │  - Iteration via         │
│  - Tier labels          │                │    jj squash / jj edit   │
│  - Periodic git commit  │                │  - Code is the           │
│    of .beads/ as backup │                │    artifact              │
└─────────────────────────┘                └──────────────────────────┘
```

- Beads is the **work-item layer**. Tasks live there.
- JJ is the **code layer**. Each commit references one (or more) bead
  ids in its description.
- The two are linked by the **bead id** (e.g., `bd-a3f8`), nothing
  more. No wrappers, no shims.
- `.beads/` (Dolt embedded DB) is git-tracked and committed
  periodically as a backup. Adding a task does not auto-create a
  git commit.

## 4. Devshell setup

### 4.1 nix-config flake input

Add to `~/nix-config/flake.nix` (or wherever the root flake lives):

```nix
inputs.beads = {
  url = "github:gastownhall/beads";
  # Pin a release tag once the cadence is known; main is fine for now.
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Note that gastownhall/beads' flake pins `nixos-25.11` and does **not**
use flake-utils. The `inputs.nixpkgs.follows = "nixpkgs";` line keeps
your nix-config from pulling a second nixpkgs into the closure.

### 4.2 Replace `~/nix-config/devshells/features/beads.nix`

Current `beads.nix` exposes the `br` binary from beads_rust. Rewrite
to expose `bd` from gastownhall/beads. Sketch (exact shape depends on
how your nix-config feature modules consume `inputs`):

```nix
{ inputs, pkgs, ... }:
{
  packages = [
    inputs.beads.packages.${pkgs.system}.default
  ];

  shellHook = ''
    # bd auto-completes on tab; safe to source on shell entry
    if [ -z "$BEADS_NO_AUTOCOMPLETE" ]; then
      eval "$(bd completion bash 2>/dev/null || true)"
    fi
  '';
}
```

If your features module convention is `mkShell`-style instead of the
flake-parts shape above, adjust accordingly — the binding I'd need to
get this exactly right is the existing `beads.nix` content, which I
haven't read. **Worth me reading it before you commit the rewrite.**

### 4.3 What about `br` in repos still using it?

`stac-forui-components` continues with beads_rust under Gemini. Two
options:

- **Keep both features available.** Rename the new feature to
  `beads-bd.nix` and leave the old `beads.nix` (= `br`) alone.
  Per-project flakes pick whichever they want. Cleaner during
  transition.
- **Cut over.** Replace `beads.nix` outright; stac-forui-components
  loses the `br` binary in-shell but the `.beads/` directory is just
  data — Gemini can still read the JSONL.

I'd recommend the first; it's cheaper, and the second buys you
nothing once stac-forui-components is in maintenance mode.

## 5. Agent access: CLI, not MCP

Decision: agents use `bd` via the shell. No MCP server.

### 5.1 Why

MCP would auto-inject tool definitions and standardize JSON returns,
but `bd` is a fast CRUD CLI — not stateful or streaming, and
structured output is a `--json` flag away. The cost (Python
dependency for `beads-mcp`, per-project server registration, another
process to monitor) outweighs the marginal benefit. A `CLAUDE.md` /
`conventions.md` section documenting the `bd` command surface
is enough for agents at every tier.

The Python concern goes away entirely. The Go devshell from §4 is
all that's needed.

### 5.2 Agent command surface (to land in `conventions.md`)

These are the operations any agent needs to know about. Verify the
exact flags against `bd --help` once the tool is installed; this is
the intended shape, not a verbatim copy.

```bash
# Discover work the agent is allowed to pick up
bd ready --label tier:<tier> --json

# Claim a task atomically (assignee = agent identity)
bd update <id> --claim --json

# Read full task context before starting
bd show <id> --json

# Update status mid-work (optional)
bd update <id> --status in_progress

# Create a new task (e.g., spinning off discovered subwork)
bd create "Title" --priority <0-3> --label tier:<tier> --label <area> --json

# Add dependency between tasks
bd dep add <child-id> <parent-id> --type blocks

# Close a task on completion
bd close <id> "<close reason>"
```

### 5.3 Output discipline

- All read commands invoked by agents should pass `--json` and parse
  the result. Avoid grepping the human-readable table format —
  brittle across `bd` upgrades.
- Write commands (`update`, `create`, `close`) can rely on exit code
  + `--json` to confirm success.

### 5.4 What if we want MCP later?

If the CLI starts feeling clumsy at scale (many agents in parallel,
deep `bd` interactions per task), we can add MCP later — `bd` is the
same binary either way. Re-evaluate only when concrete pain shows up,
not preemptively.

## 6. Tier labels for agent delegation

### 6.1 Vocabulary

```
tier:opus      # architecture, design, tricky bugs, code review
tier:sonnet    # feature implementation, routine refactors
tier:haiku     # simple tests, small fixes, formatting
tier:local     # commits, file moves, mechanical work — local LLM tier
tier:any       # any agent can pick this up (default)
```

Optional secondary label for delegation context:

```
reason:design       # why opus: needs new abstractions
reason:mechanical   # why local: pure transformation
reason:review       # why opus: judgment call needed
reason:research     # any: gather info before decision
```

### 6.2 Dispatcher pattern

A lower-tier agent (or you) does:

```bash
bd ready --label tier:sonnet    # what can a Sonnet pick up right now?
bd update <id> --claim          # atomically claim it
# do the work in JJ commits referencing <id> in the description
bd close <id> "<close reason>"  # when done
```

This pattern is what gastownhall/beads is built for. We don't need
a custom dispatcher — `bd ready` plus discipline about labels is
enough.

### 6.3 Setting tier at task creation

Default `tier:any` if unspecified. When *I* (or any agent) creates a
task, set tier explicitly to match the task's actual difficulty.
Default to higher tier if unsure — easier to downgrade than to
discover mid-task that a low-tier agent is in over its head.

## 7. JJ + bd integration

### 7.1 Commit message convention

```
[bd-a3f8] Implement FCard renderer

Maps StacForuiCard's title / subtitle / child to FCard slots.
See bd-a3f8 for context and acceptance criteria.

Refs: bd-a3f8
Closes: bd-a3f8.1, bd-a3f8.2
```

- **First-line tag** `[bd-XXXX]` — visible in `jj log` summaries.
- **`Refs:` footer** — for tasks the commit *advances* but does not
  finish.
- **`Closes:` footer** — for tasks the commit completes (the agent
  should also `bd close` them; the footer is for human auditability).

Subject to your preference — the git/JJ convention for this is yours
to set, the above is just the most boring sane default.

### 7.2 Iteration cycle

The JJ "iterate on a commit until correct" workflow you described
maps cleanly here:

1. `bd update <id> --claim` (status → in_progress, assignee = you).
2. `jj new` — start a working commit with `[bd-XXXX]` description.
3. Iterate: edit, `jj squash`, `jj describe`, etc. Same commit grows
   correct.
4. When done: `bd close <id> "<reason>"`, then merge / push.

The `assignee` set by `--claim` is your handle (`bhougland`,
`opus-4.7`, or whichever convention). For multi-agent runs, the
assignee is the *agent identity*, not the human — that's how `bd
ready` filters out claimed work.

### 7.3 Don't over-design

Resist the temptation to write a `jj-bd` wrapper that auto-syncs the
two. Convention in commit messages is enough. If we later find
ourselves doing the same five steps repeatedly, *then* a small
script earns its keep.

## 8. Per-repo rollout

### 8.1 zeroflat (now)

- `cd ~/code/zeroflat && bd init --skip-hooks` (see §8.5 for the
  rationale).
- Create initial epics: `Schema`, `Renderer`, `Theme`, `Lens`,
  `Forms`, `P2P` (deferred). Plus the immediate tasks from the
  evaluation doc's phase plan.
- First commit will include `.beads/` initialization.

### 8.2 stac-forui-components (no change)

Frozen on beads_rust under Gemini. `.beads/` stays as-is. This plan
does not touch it.

### 8.3 conduit and others

Per-repo when each repo's owner wants to move. Not blocking.

### 8.4 Future repos

`bd init --skip-hooks` from day one. Becomes the default via the
updated `~/nix-config/devshells/features/`.

### 8.5 Why `--skip-hooks`

By default `bd init` installs git hooks (`pre-commit`, `post-merge`,
`pre-push`) that run beads-data consistency checks and Dolt-DB
syncs. Two reasons to skip them:

- **JJ compatibility.** JJ's git operations don't always traverse
  the same code paths as `git commit`/`git pull`, so the hooks can
  fire at unexpected times or fail silently when you'd expect them
  to fire. The upstream doc explicitly recommends `--skip-hooks`
  for "branchless workflows" — JJ qualifies.
- **Tool-owned hooks are surprising.** Pre-commit hooks installed
  by a non-VCS tool can block commits for reasons unrelated to the
  code change, which is the kind of thing that sends you on a
  debugging detour at the worst time.

`bd` itself does *not* auto-commit on create/update/close. The doc
states verbatim: "beads does not commit to any Git branch." The
hooks are the only git-side effect, and `--skip-hooks` cleanly
removes it.

## 9. Sequencing

1. **Read `~/nix-config/devshells/features/beads.nix`** (the existing
   beads_rust one) so I can write the replacement against your
   actual flake-parts/perSystem conventions. ~5 min.
2. **Try `nix run github:gastownhall/beads` in a throwaway dir** to
   confirm `bd init` and `bd create` work cleanly. Capture the actual
   `bd --help` output to verify the §5.2 command surface. ~10 min.
3. **Update nix-config:** add `inputs.beads`, write the new feature
   file (or a renamed one preserving the `br`-flavored one for
   stac-forui-components compatibility). ~30 min.
4. **`bd init` zeroflat**, create initial epics + tasks from the
   evaluation phase plan. ~20 min.
5. **Write `conventions.md`** with the tier vocabulary, JJ commit
   convention, and agent CLI surface so the next agent that walks
   in finds the rules pinned. ~20 min.

Total: ~1.5 hours of focused work to fully cut over. (Down from ~2
hours after dropping MCP.)

## 10. Open items

- **Pin gastownhall/beads to a release tag** once the cadence is
  understood. `main` is fine for week-one but exposes you to drift.
- **Decision-store strategy.** I'm assuming `docs/adr/NNN-title.md`
  per ADR (the standard format). If you want richer search over
  decisions later, that's when Medulla's semantic search comes back
  on the table — but only when there's enough decision volume to
  matter. Not now.
- **Backup strategy for `.beads/`.** Dolt's embedded mode supports
  `bd backup {init,sync,restore}`. Worth setting up the first time
  the data feels precious; not before.
- **Agent identity convention.** When a Claude Code session claims
  a task, what's the assignee string? `claude-opus-4-7-bhougland`?
  `opus-4.7`? Pick a convention before multiple agents work in
  parallel; otherwise audit logs get mushy.
- **Delete the Medulla fork?** Zero-cost to leave; one click to
  delete. Recommend leaving for ~30 days in case we change our minds,
  then deleting if untouched.

## 11. Bottom line

- Smaller plan than Medulla's. ~1.5 hours from "yes" to fully cut over.
- No fork tax. Active upstream.
- Multi-agent primitives free out of the box.
- CLI-only (no MCP), so the Python concern is moot. The Go devshell
  is everything we need.
- ADR coverage by markdown in `docs/adr/`. Revisit semantic-search
  need when there's enough volume to feel the lack.

When you say go, I'll execute steps 1–3 in §9 and report back before
running `bd init` against zeroflat.
