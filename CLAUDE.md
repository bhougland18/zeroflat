# zeroflat

Local-first body-asymmetry / mental-state tracking app. Rust core + Flutter UI + P2P. Design phase — no code yet, only `documents/` and an empty `schema/`.

## Stack (PRD v1.1, with 2026-05-04 bridge-format split)

| Layer | Choice |
|---|---|
| Storage + P2P | GuardianDB (Iroh-Docs/Willow + Iroh-Blobs + Iroh-Gossip) |
| Wire format (storage + P2P) | Postcard (Rust↔Rust, no schema seam) |
| **UI bridge format** | **FlatBuffers with Dart codegen via Rinf binary signals — schema-first at the Dart seam. Bridge types are narrow ViewModels (FormView, FormListItem, Patch, StacNode), projected from storage types in a `project_for_ui` layer — not 1:1 mirrors.** |
| Orchestration | Conduit FBP for long-lived flows (input/sync/indexer/hot-reload); direct asupersync for one-shot Rinf handlers and app glue |
| Search | FrankenSQLite FTS5, populated by a Conduit pipeline |
| Identity / E2EE | Iroh Ed25519 keys, OS keyring (XChaCha20-Poly1305 at-rest) |

## Read first

- `documents/integrated_architecture_v2.md` — execution plan. Was written under "postcard everywhere"; §2, §3, §6, §9.5, §11 are pending an update for the 2026-05-04 bridge-format split (FlatBuffers re-introduced at the Rinf bridge).
- `documents/PostMaster_PRD_v1.1.json` — canonical PRD (May 2026).
- `documents/components.md` — Forui component vocabulary (~15 components). Status banner marks which sections are superseded.
- Historical / period-record (don't retroactively rewrite): `zeroflat_evaluation.md`, `zeroflat_initial_proposal.json`, `medulla_migration.md`.

## Open with Ben

- Whether to update integrated_architecture_v2.md in place or write a v3 that supersedes its §2/§3/§6/§9.5/§11.
- `components.md` v2 (vocabulary same, codegen/SoT framing back to .fbs for bridge types).

## Conventions

- Design docs are dated, versioned, and explicitly mark themselves SUPERSEDED when replaced.
- Task tracking via gastownhall/beads (`bd` CLI), per-repo `.beads/` directory. **`.beads/` is not yet initialized in this repo — don't `bd init` without explicit go-ahead from Ben.**
- Repo was briefly renamed to "Postmark" (2026-05-03 → 2026-05-04); reverted because FlatBuffers is back in the stack at the bridge. See `project_repo_rename_history.md` in memory.
- Full project context lives in memory at `~/.claude/projects/-home-ben-code-zeroflat/memory/` — `MEMORY.md` is the index.
