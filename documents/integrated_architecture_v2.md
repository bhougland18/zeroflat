---
title: Integrated Architecture v2 — Postcard / GuardianDB / Conduit
date: 2026-05-03
author: Claude (Opus 4.7), in dialogue with Ben
status: Active — supersedes zeroflat_evaluation.md §3.1, §3.2, §3.3 and components.md §0–§3 codegen framing
relates_to:
  - PostMaster_PRD_v1.1.json (current PRD; this doc is its execution plan)
  - zeroflat_evaluation.md (FlatBuffers-era reasoning; vocabulary survives, format-specific guidance does not)
  - components.md (component vocabulary survives; codegen / schema-evolution / SoT framing replaced by §6 below)
  - ../conduit/docs/archetecture/proposal_structured_payloads.md (Conduit-side change this depends on)
upstream_deps:
  - GuardianDB v0.16.x (https://github.com/wmaslonek/guardian-db) — Postcard + Iroh-Docs/Willow + Iroh-Blobs + Iroh-Gossip + BLAKE3
  - Conduit (~/code/conduit) — Ben's FBP engine; orchestrates long-lived flows
  - Iroh — hidden behind GuardianDB
  - Rinf — Rust↔Flutter bridge with RustSignalBinary/DartSignalBinary
  - Forui — Flutter widget library, ~0.21.x
---

# Integrated Architecture v2 — Postcard / GuardianDB / Conduit

## 1. What this doc is

The PRD v1.1 picked the stack (Postcard + GuardianDB + Conduit + Rinf
+ Forui). This doc is the **execution plan** for that stack: how the
pieces compose, where the boundaries are, what gets built first, and
what's deliberately deferred.

**Key Boundary Clarification:**
ZeroFlat Flutter is a **pure renderer**. It has zero knowledge of
GuardianDB, P2P sync, or the Conduit workflow engine. Its sole
responsibilities are:
1.  **Receive:** Decode Postcard/FlatBuffer UI trees from Rust via Rinf.
2.  **Render:** Map those trees into Forui widget hierarchies.
3.  **Emit:** Catch user interactions (taps, text changes) and send them
    as typed `StacAction` signals back to Rust.

All logic, state management, storage, and networking (P2P) reside
exclusively in the Rust core.

## 2. Stack — verified

| Layer | Choice | Status as of 2026-05-03 |
|---|---|---|
| Storage + P2P | GuardianDB v0.16.x | Real crate, 847 tests, "active development, breaking changes expected" — early-adopter zone, not production |
| Wire format | Postcard/FlatBuffers | Postcard for DB/P2P; FlatBuffers for UI bridge (safety + codegen) |
| Orchestration | Conduit FBP for long-lived flows; direct asupersync for one-shots | Conduit is at v0.1.0, 67/95 beads closed, FBP core landed; pending: structured payloads (proposal filed) |
| UI bridge | Rinf with `RustSignalBinary` / `DartSignalBinary` | Mature; transport zero-copy across FFI |
| Renderer | Custom Forui-mapping layer (~15 components) | ~80% of vocabulary harvestable from `~/code/stac-forui-components` |
| Search | FrankenSQLite (FTS5), populated by a Conduit pipeline | Standard FTS5; Rust-side indexer derives text from new GuardianDB writes |
| Analysis | Separate app: Postcard blobs → RDF triples → SPARQL via Kolibrie | Out of main app process; main app does not carry Kolibrie weight |
| Identity / E2EE | Iroh Ed25519 keys, OS keyring (XChaCha20-Poly1305 at-rest) | Hidden behind GuardianDB |

## 3. Layered picture

```
                    ┌───────────────────────────────────────┐
                    │ Flutter (Pure Renderer)                │
                    │   Registry & Dispatcher               │
                    │   Forui mapping (~15 components)      │
                    │   FlatBuffer decode                   │
                    │   Local controllers (state-less)      │
                    └────────────────┬──────────────────────┘
                                     │ Rinf (flatbuffer bytes)
                                     │ UI Tree (Rust -> Dart)
                                     │ Actions (Dart -> Rust)
                    ┌────────────────┴──────────────────────┐
                    │ Rust (Core Logic)                     │
                    │                                       │
                    │  ┌─────────────────────────────────┐  │
                    │  │ Conduit workflows (The Brain)    │  │
                    │  │  - input pipeline (taps→ops→DB) │  │
                    │  │  - sync pipeline (Iroh→merge→UI)│  │
                    │  │  - FTS5 indexer                 │  │
                    │  │  - UI Tree Projector            │  │
                    │  └────────┬────────────────────────┘  │
                    │           │ asupersync (substrate)    │
                    │  ┌────────┴────────────────────────┐  │
                    │  │ Direct async                    │  │
                    │  │  - Rinf request handlers        │  │
                    │  │  - app glue / startup           │  │
                    │  │  - one-shot DB queries          │  │
                    │  └────────┬────────────────────────┘  │
                    │           │                           │
                    │  ┌────────┴────────────────────────┐  │
                    │  │ GuardianDB (Storage & P2P)      │  │
                    │  │  DocumentStore  → forms (Postcard)│
                    │  │  EventLogStore → tap-stream ops │  │
                    │  │  KeyValueStore → app config     │  │
                    │  └────────┬────────────────────────┘  │
                    │           │ Iroh-Docs/Willow,         │
                    │           │ Iroh-Blobs, Iroh-Gossip   │
                    └───────────┴───────────────────────────┘
                                │
                          ◄── P2P (postcard wire, BLAKE3 hashes,
                                   E2EE via Iroh/Willow) ──►
```

## 4. Conduit vs asupersync — split decision

Use Conduit for the **load-bearing long-lived flows**; use direct
asupersync for **one-shot glue**. Don't force everything through
Conduit.

| Use Conduit for | Why |
|---|---|
| Input pipeline: tap → CRDT op → buffer → GuardianDB commit | Long-running, needs backpressure metering, observable |
| Sync pipeline: Iroh inbound → Willow merge → derived state → Rinf out | Multi-input stream-join shape, exactly what Conduit is built for |
| FTS5 indexer: GuardianDB writes → text derivation → SQLite | Fan-in derivation, want queue-pressure visibility |
| Dev hot-reload: file watcher → UI delta → Rinf | Same shape as production UI delivery — clean reuse |
| Future: analysis app's RDF mapping pipeline | Long-running, observable, multi-input |

| Use direct asupersync for | Why |
|---|---|
| Rinf request handlers (Flutter asks for form list → Rust queries → returns) | One-shot, no flow shape, ceremony-free |
| App startup / shutdown sequencing | Linear, no backpressure concern |
| Synchronous DB lookups inside Conduit nodes | The node *is* the unit; don't nest Conduits |

The sub-100ms UI requirement is **measurable per edge** when flows go
through Conduit's bounded ports + queue-pressure metadata. That's the
strongest single argument for Conduit over raw asupersync for the
flows above.

## 5. Storage model mapping

| Domain object | GuardianDB store | Postcard type | Notes |
|---|---|---|---|
| Completed form (the canonical artifact) | `DocumentStore` | `Form { schema_version, fields, ... }` | One form = one document. PRD F2 alignment. |
| Tap-stream / form-edit ops | `EventLogStore` | `EditOp { schema_version, op, target, value, timestamp }` | Immutable per-event entries. PRD F1, F3 alignment. Events are append-only — schema-evolution discipline matters most here (see §7). |
| App config / per-screen UI state | `KeyValueStore` | `UiState { schema_version, screen_id, payload }` | Last-write-wins fits cleanly. |
| Encrypted at-rest blobs | (handled by GuardianDB) | n/a | XChaCha20-Poly1305 at-rest, key in OS keyring. |
| FTS5 search index | (separate FrankenSQLite DB, not in GuardianDB) | n/a | Derived data; rebuild from GuardianDB if lost. |

UI definitions (the Forui component trees) **are not stored in
GuardianDB** in v1 — they ship in the app bundle. This sidesteps the
homebase OTA security question (§9.4) until we explicitly decide to
take it on.

## 6. Component vocabulary — what survives, what changes

`components.md` was written assuming `.fbs` files were the source of
truth and a `flatc --rust --dart` codegen pipeline. With Postcard, the
SoT shifts.

**Survives verbatim:**

- The component list (Theme, Scaffold, Header, Divider, Button,
  TextField, Switch, Checkbox, Card, Dialog + the §6.5 candidates).
- Per-component fields, types, defaults, enum values.
- `StacAction` union vocabulary (`ActionUpdateState`, `ActionNavigate`,
  `ActionShowDialog`, `ActionShowSheet`, `ActionShowToast`,
  `ActionCustom`).
- Token vocabulary (`ColorToken`, `TypographyToken`, `Brightness`).
- The `id` contract (stable, author-supplied, used for deltas + Patrol
  finders).
- The worked examples (login screen, settings toggle).

**Changes (needs a `components.md` v2 rewrite):**

| Was (fbs era) | Is (postcard era) |
|---|---|
| `.fbs` files are SoT; codegen Rust + Dart bindings via `flatc` | Rust types in a shared crate are SoT; Dart types via Rinf binary-signal codegen or hand-mirrored |
| `StacNode` = fbs union | `enum StacNode { Theme(Theme), Scaffold(Scaffold), ... }` derived with `serde::Serialize` + `serde::Deserialize`, sent through Conduit as `PostcardPacket<StacNode>` |
| Schema evolution = fbs append-only field IDs | Schema evolution = versioned envelope at each persisted boundary; append-only struct fields; round-trip fixture tests (§7) |
| Agent emits JSON; toolchain converts to fbs | Agent emits JSON-shaped payload; toolchain runs `serde_json → T → postcard::to_allocvec` |
| Hot-reload writes `current_ui.fb` | Hot-reload writes `current_ui.postcard` (or JSON for legibility, converted at watch time) |

`components.md` v2 is a follow-on doc, not part of this one. The
vocabulary content carries over; the framing sections do not.

## 7. Schema-evolution discipline

Postcard does not give you fbs-style append-only safety in the format
itself. We carry it in the envelope. The discipline is short and
non-negotiable:

1. **Versioned envelope on every persisted struct.** Every `T` that
   lands in GuardianDB is wrapped:

   ```rust
   #[derive(Serialize, Deserialize)]
   struct Envelope<T> {
       schema_version: u16,
       payload: T,
   }
   ```

2. **Fields are append-only.** No insertion mid-struct. No removal.
   No reordering. No type changes on existing fields.

3. **Enum variants are append-only.** No reordering existing
   variants. New variants go at the end.

4. **Fixture round-trip tests.** Every schema PR adds a fixture in
   `tests/fixtures/<type>/v<n>.postcard` and a test that decodes
   every previous version's fixture into the current type. CI fails
   if an old fixture stops decoding.

5. **`EventLogStore` entries are the highest-risk surface.** They're
   immutable; old entries will outlive every schema change. Wrap
   every event variant in the versioned envelope individually, not
   just at the outer enum.

6. **Schema migration on read, never on write.** When schema_version
   < current, the read path runs a migration function. Writes always
   use current. Migrations are pure functions, unit-tested.

This adds maybe 30 lines of glue per type. Skipping it costs days the
first time a peer running v1 sync-merges with a peer running v2.

## 8. The Conduit dependency we're adding

Zeroflat needs Conduit's `Structured(Arc<dyn DataPacket>)` payload
variant + a `serde-postcard` feature that provides
`PostcardPacket<T>`. Filed as a proposal at:

`~/code/conduit/docs/archetecture/proposal_structured_payloads.md`

Five candidate beads listed there; bead 1
(`core-data-packet-trait`) is the foundation. Until it lands,
zeroflat code can either:

- **Pre-serialize to bytes at every Conduit edge** using
  `PacketPayload::Bytes(postcard::to_allocvec(&t)?.into())` —
  works today, but pays encode+decode at every hop. Fine for a
  spike; not the long-term shape.
- **Wait** for the Conduit beads to land before wiring Conduit-based
  flows.

Recommendation: spike with the bytes-at-every-edge shape so the spike
is not blocked, then convert to `Structured` once the Conduit feature
lands. The conversion is a search-and-replace.

## 9. Concerns being explicitly tracked

### 9.1 GuardianDB maturity

v0.16.x with breaking changes expected. Plan: pin a specific version
(e.g., `=0.16.3`), schedule quarterly upgrade work, write a
fixture-based integration test that exercises the three store types
end-to-end so upgrades are validated against real workloads, not just
their own changelog.

### 9.2 LWW vs concurrent edit semantics

GuardianDB's Willow uses Last-Write-Wins. For body-asymmetry /
mental-state forms with **one author per device-identity**, LWW is
correct. If two devices ever concurrently edit the same form field
offline (e.g., a couple sharing a tablet, a two-person assessment),
LWW silently drops one edit. **Decision needed:** confirm the
single-author assumption holds, or design a per-field CRDT type for
the affected fields. Not blocking v1 unless the use case appears.

### 9.3 Conduit as early-consumer dependency

Building zeroflat on Conduit at v0.1.0 stacks two pre-production
bets. Mitigation: Conduit is yours, so when it breaks zeroflat you
fix it at the source. That coupling is actually *desired* — zeroflat
will surface Conduit API issues that no other consumer would.
Allocate ~20% of zeroflat dev time to Conduit fixes for the first
six months.

### 9.4 Homebase OTA scope

The earlier evaluation doc imagined a "homebase OTA" channel for
shipping UI updates outside the app store. Status: **deferred, not
killed.** v1 ships UI definitions in the app bundle. Reopening this
question requires a security design (peer pushing a UI def is
functionally a code-update channel — same posture as code signing).
Not on the v1 critical path.

### 9.5 Rinf binary-signal Dart codegen

Need to verify what Rinf's `DartSignalBinary` codegen does for complex
nested types. Worst case: hand-mirror the Dart types from the Rust
postcard schema. Tractable at ~15 components; spike will surface this.

## 10. Repo rename history

Project name has flipped twice:

- **2026-05-03:** zeroflat → Postmark. Rationale at the time: "flat" referred to FlatBuffers, which v1.1 PRD removed in favor of postcard everywhere.
- **2026-05-04:** Postmark → zeroflat (revert). Rationale: postcard at the Rinf bridge offered no schema safety for the Dart side; decision is to keep postcard for storage and P2P wire and reintroduce **FlatBuffers** at the UI bridge with Dart codegen and ViewModel-projection bridge types (not 1:1 mirrors of storage). With FlatBuffers back in the stack at the seam where it matters most for Dart safety, the original name fits again.

Filesystem move is a manual user step (Claude can't `mv` its own working directory):

```bash
mv ~/code/postmark ~/code/zeroflat
mv ~/.claude/projects/-home-ben-code-postmark \
   ~/.claude/projects/-home-ben-code-zeroflat
cd ~/code/zeroflat
```

Historical docs (the dated evaluation, the original proposal, the medulla migration) kept "zeroflat" in their bodies as period record across both renames; they need no further changes.

## 11. Sequencing — what to build first

### Phase 0: Prove the spine end-to-end (1–2 weeks)

1. **GuardianDB → FTS5 spike.** Standalone Rust binary: write a
   `Form` to `DocumentStore`, derive text from it, insert into
   FrankenSQLite FTS5, query it back. Proves the storage→search loop
   without touching Conduit, Rinf, or Flutter. Surfaces version
   pinning issues, the FrankenSQLite + GuardianDB build interaction,
   and the schema-envelope shape.
2. **Rinf binary-signal round trip.** Smallest possible Flutter +
   Rust app: send a postcard-encoded `Patch` from Rust to Dart, log
   it in Flutter. Proves Rinf's `DartSignalBinary` decode story for
   a real type.
3. **Conduit minimal pipeline.** A 2-node Conduit workflow that
   bridges (1) and (2): GuardianDB write → Conduit edge →
   serialized payload → mock Rinf out. Uses bytes-at-every-edge
   pattern (see §8) until the Structured beads land.

### Phase 1: First real screen (2–3 weeks)

4. `components.md` v2 (vocabulary same, codegen/SoT framing replaced
   per §6).
5. ADR: Postcard schema-evolution discipline (the §7 rules formalized).
6. Forui mapping layer for ~5 components (Theme, Scaffold, Header,
   Card, Button) harvested from stac-forui-components.
7. One end-to-end screen: open app → see one form → edit one field →
   save → reopen and see saved value. All paths real (Conduit + DB +
   Rinf + Forui).

### Phase 2: Scale the surface (3–4 weeks)

8. Remaining ~10 components.
9. Action vocabulary wiring (`ActionUpdateState` → Conduit input
   pipeline → DB).
10. FTS5 search UI.
11. Settings + multi-form flows.

### Phase 3: P2P sync (2 weeks)

12. Wire GuardianDB sync between two device-instances on the same
    network.
13. Identity flow (Ed25519 key, QR pairing).
14. LWW behavior verification (re §9.2).

### Phase 4 (deferred to its own design session)

- Analysis app + Kolibrie RDF mapping.
- Homebase OTA channel + signing (§9.4).
- ZK security pieces.

## 12. Open items

These either need a decision or surface a research need before the
relevant phase:

- **Conduit Structured beads** — when does bead 1
  (`core-data-packet-trait`) land? Affects whether Phase 1 uses
  bytes-at-every-edge or `Structured` from the start.
- **Rinf complex-type codegen** — to be answered by Phase 0 step 2.
- **GuardianDB version pin** — pick before Phase 0 step 1.
- **Repo rename** — pick before Phase 1 (touches imports if Cargo
  workspace gets a name).
- **LWW decision** — needs explicit single-author confirmation before
  Phase 3.
- **Schema-envelope macro** — worth writing a derive macro for the
  `Envelope<T>` pattern? If we have >5 persisted types, yes; if 2–3,
  hand-roll.

## 13. References

- `PostMaster_PRD_v1.1.json` — current PRD, this doc executes against it
- `zeroflat_evaluation.md` — predecessor reasoning; vocabulary lives,
  format-specific guidance superseded
- `components.md` — component vocabulary lives, codegen/SoT framing
  superseded by §6 here; v2 rewrite is a follow-on
- `beads_migration.md` — task tracking plan (active, separate workstream)
- `~/code/conduit/docs/archetecture/proposal_final.md` — Conduit
  current strategy
- `~/code/conduit/docs/archetecture/proposal_structured_payloads.md` —
  the Conduit change zeroflat depends on
- GuardianDB: https://github.com/wmaslonek/guardian-db
