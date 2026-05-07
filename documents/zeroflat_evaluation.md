---
title: ZeroFlat — Evaluation & Plan Sketch
date: 2026-05-01
author: Claude (Opus 4.7), in dialogue with Ben
status: PARTIALLY SUPERSEDED — see integrated_architecture_v2.md (2026-05-03)
superseded_sections:
  - §3.1 (ID-based delta protocol) — GuardianDB/Willow now handles this
  - §3.2 (hot-reload carrier) — see integrated_architecture_v2.md §11 Phase 0
  - §3.3 (fbs schema as artifact) — replaced by Postcard + versioned envelope discipline
  - §5 sequencing — replaced by integrated_architecture_v2.md §11
  - All references to FlatBuffers as wire format — replaced by Postcard
preserved_sections:
  - §2 ("Why this looks viable now") — reasoning still applies, swap "fbs" for "Postcard"
  - §3.4 (Forui API churn / thin mapping layer) — still correct
  - §3.5 (CRDT/RDF/ZK design session deferral) — partially answered by GuardianDB; ZK still pending
  - §4 (reusable from stac-forui-components) — vocabulary and Forui knowledge still apply
  - §6, §7 (bottom line + immediate next steps) — superseded by v2
relates_to:
  - integrated_architecture_v2.md (current plan; 2026-05-03)
  - zeroflat_initial_proposal.json (original proposal)
upstream_deps:
  - Conduit (~/code/conduit) — Ben's FBP engine
  - Asupersync (https://github.com/Dicklesworthstone/asupersync) — Rust async runtime under Conduit
  - Iroh — Rust P2P crate, planned for tablet↔phone delta sync
  - Forui — Flutter UI library
  - Rinf — Rust↔Flutter isolate bridge
---

# ZeroFlat — Evaluation & Plan Sketch

## 0. What changed since the first draft

The first draft asked nine clarifying questions. Your answers reshape the
evaluation enough that I'd rather rewrite it than annotate it. The short
version of what changed:

- **Branch confirmed:** local-first app, Rust on-device, P2P sync via Iroh,
  not a server-driven SDUI replacement. fbs is the wire format because of
  sensors and the planned homebase OTA channel — not despite the in-process
  case.
- **Conduit + Asupersync are real upstream deps you own or use directly**,
  not vague promises. The "Rust runs rules" loop is grounded.
- **AI-as-designer is a dev-time workflow**, not a product feature. The
  agent (me, or another) authors fbs payloads while you iterate; nothing
  AI-related ships in the binary. This collapses the largest concern in
  draft 1.
- **Component count is ~15 total**, not 30+. The repo's current pace says
  that's a few weeks of focused work, not months.
- **Some pieces are explicitly still in flux** (CRDT/RDF, P2P, ZK security
  — design session pending). This document does not try to lock them down.

The verdict moved from *"feasible if scoped, with caveats"* to
*"viable, with three mechanisms still to pin down."* The "build a
minimum UI library" framing now reads to me as the right call for this
specific app, given the constraints you described.

---

## 1. The picture, restated

```
┌─────────────────────────────────────────────────────────────────┐
│ Device                                                          │
│                                                                 │
│  ┌─────────────────────┐  Rinf channel (fbs)  ┌──────────────┐  │
│  │ Rust                │ ───────────────────► │ Flutter      │  │
│  │  - Conduit (FBP)    │                      │  - Renderer  │  │
│  │  - RDF state store  │ ◄─────────────────── │    (Forui)   │  │
│  │  - KV cache         │  controller updates  │  - Lens      │  │
│  │  - Iroh P2P node    │                      │    overlay   │  │
│  │  - Asupersync       │                      │              │  │
│  └──────────┬──────────┘                      └──────────────┘  │
│             │ P2P (iroh)                                        │
└─────────────┼───────────────────────────────────────────────────┘
              │
   ┌──────────┼──────────────────┐
   │          ▼                  │
   │  Other peers (tablet,       │   ┌─────────────────────────┐
   │  phone, homebase node) ─────┼──►│ Homebase node           │
   │  share state via CRDT       │   │  - OTA UI updates       │
   │  diffs over fbs             │   │    bypassing app store  │
   └─────────────────────────────┘   └─────────────────────────┘
```

Key invariants from the Q&A:

- **Rust owns canonical state.** Exceptions exist (you don't have one
  yet, but expect some) and should be the rare case, not the rule.
- **fbs is the wire format everywhere.** Rust↔Flutter (Rinf), peer↔peer
  (Iroh), homebase↔client (homebase OTA). One contract.
- **CRDT/RDF eventually carries both state and UI definitions.**
  Not v1 — the design session for this is still pending. v1 can
  treat UI definitions as static-per-version with a hot-reload
  channel for dev (§3.2 below). The CRDT migration becomes a wire-format
  reuse rather than a redesign.
- **Forui's own controllers**, not flutter_hooks. The audit's open P1/P2
  items (hooks story, state-management story) are answered by "use
  Forui's grain."

---

## 2. Why this looks viable now

- **The fbs argument is now coherent.** Sensors are a strong fbs case
  (continuous structured streams, possibly large). Iroh + homebase OTA
  are the network case yesterday's strategy doc was missing. Pre-investing
  in fbs to avoid a sensor-time migration is a defensible engineering
  choice. (My Q8 concern is gone.)
- **You own the dependencies that matter.** Conduit is yours. The renderer
  will be yours. The schema will be yours. The "what if upstream rejects
  the PR" failure mode you described is real with STAC — it is the exact
  reason yesterday's fbs strategy spent a lot of words on §5.4 (additive
  PR vs. fork). ZeroFlat sidesteps that argument by not having an
  upstream to negotiate with.
- **Existing repo is mostly Forui knowledge, not STAC knowledge.** §4
  below details what's reusable. The 30-component build was learning
  Forui; the STAC plumbing on top is the smaller part.
- **AI-assisted dev makes "own the renderer" cheaper than it used to be.**
  I take your "age of AI" point. Writing a custom registry + dispatcher
  + delta applier in 2026 is not the same lift it was in 2020. For a
  solo dev, the leverage tilts toward custom over wrap-and-glue.

---

## 3. Concerns that survived (sharpened, not dropped)

### 3.1 ID-based delta protocol — design space narrowed but not pinned

CRDT/RDF state actually *helps* here. If state lives in RDF triples and
syncs as CRDT diffs, the "UI delta" is a projection of changed triples
onto component ids. The delta protocol doesn't need to be invented —
it falls out of the data layer.

But: in v1, before CRDT/RDF lands, you still need a delta shape for
Rust→Flutter updates after Conduit rules fire. The cleanest move is to
**design v1's delta shape so that it is exactly the CRDT triple-change
projection it will eventually become.** Concretely:

- Each rendered component has a stable `id`.
- Each Rust→Flutter delta is an ordered list of `Patch { id, op, value }`
  where `op` ∈ `{set_prop, insert_child, remove_child, reorder}`.
- The triple-change projection in v2 emits the same `Patch` shape.
- Lock the wire shape now; the source of truth shifts later.

If that holds up under the upcoming CRDT/RDF design session, the v1
delta protocol survives that transition without a rewrite. If it
doesn't, we want to know that *before* we ship v1. Worth being a
short conversation in that design session.

### 3.2 The "REPL for UI" needs a hot-reload carrier

Mechanism for: agent emits fbs → app picks it up → renders. Three
plausible options, in increasing complexity:

| Option | Mechanism | Pro | Con |
|---|---|---|---|
| File watcher | Agent writes `current_ui.fb`; Rust watches, sends to Flutter | Trivial | Single-file constraint |
| Rinf debug channel | Agent calls a CLI tool; CLI sends fbs over a Rinf channel | Clean dev/prod split | More plumbing |
| Devtools port | Flutter devtools extension reads fbs, hot-injects | Nice UX | Most build complexity |

Recommendation: **start with the file watcher.** Promote to Rinf debug
channel if/when the workflow needs more (e.g., per-screen targeting,
agent inspection of current state).

### 3.3 fbs schema becomes a real artifact

Yesterday's flatbuffers strategy had Dart models as source of truth
and codegen'd `.fbs`. **ZeroFlat flips this:** `.fbs` files are SoT,
codegen Rust *and* Dart bindings from them. That's the orthodox
fbs approach. Implications:

- **Schema repo / directory is a versioned artifact.** PR review,
  evolution rules, append-only field discipline (yesterday's
  doc §6.5 still applies — we just need to enforce them).
- **Schema includes the component vocabulary.** This is also what
  the agent's skill file documents (§7).
- **Codegen pipeline runs in two languages.** `flatc --rust`,
  `flatc --dart`. Both should run as part of the build, not committed
  artifacts, so the schema is the only thing reviewed.
- **One pre-commit check:** schema-evolution guard (no field deletion,
  no enum reordering, no union tag reuse). Dropping this discipline
  even once will cost more than maintaining it.

### 3.4 Forui's API surface shifts. Plan for it.

Forui is at 0.21.x; we already had to migrate from 0.1.x earlier in
this repo. ZeroFlat will face the same upgrade tax. The mitigation is
**keep the Forui-mapping layer thin and isolated** so a Forui major
version bump touches only `mapping/` files, not Conduit, not the
schema, not the dispatcher. The current repo already does this well —
worth preserving the property in ZeroFlat from day one.

### 3.5 Things the upcoming design session will affect

The CRDT/RDF/ZK design session will affect at minimum:

- The delta protocol shape (§3.1).
- Whether UI definitions sync via CRDT or are signed app-bundle
  artifacts only (security implications: who can author fbs that
  reaches a peer? ZK-based attestation, code-signing, both?).
- The homebase trust model (a homebase node pushing fbs to a client
  is functionally a code-update channel — it needs the same security
  posture as code signing).

**Recommendation:** treat ZeroFlat v1 as "single-device, no P2P,
no CRDT, no ZK" — keep the wire format and delta shape forward-
compatible, but defer the distributed pieces to v1.5/v2 after the
design session. This is not a technical limitation; it's
sequencing to avoid building on decisions that aren't made yet.

---

## 4. Reusable from `stac-forui-components`

Inventory ranked by reuse value. Rough estimate of what was learned.

### 4.1 High-value reuse (copy with light edits)

- **Per-component models (~32 files in `lib/src/models/`).** These
  encode the field surface for each Forui component — what's optional,
  what variants exist, the size/style enums and their `to*Variant`
  getters. Strip `@JsonSerializable` and the `StacWidget` superclass;
  the rest is pure Forui knowledge. **This is the bulk of the 2 weeks.**
- **Forui-mapping bodies in parsers (`lib/src/parsers/*.dart`).** Each
  `parse(...)` body — how a model becomes an `FButton`, prefix/suffix
  slot handling, controller attachment, `KeyedSubtree` wrappers for
  Forui widgets that don't accept `key` — is identical logic in
  ZeroFlat. Drop `StacParser`, drop `Stac.onCallFromJson`, the rest
  is reusable.
- **Token vocabulary (in flight under audit RT1–RT7).** Land it in this
  repo first as planned; copy verbatim into ZeroFlat. The
  `memory/project_theme_strategy.md` decision was already shaped to
  serve a future binary-protocol library — ZeroFlat is the consumer
  it was shaped for.
- **Test utilities** (`test/stac_forui_test_utils.dart`,
  `MockActionParser`, the find-by-key pattern). The Patrol-style
  testing approach is identical to ZeroFlat's needs. Adapt the mock
  layer to ZeroFlat's action shape; the test patterns themselves port.

### 4.2 Medium-value reuse (reference, don't copy)

- **Component coverage matrix.** ~30 components implemented; ZeroFlat
  needs ~15. The existing list is the menu.
- **Action infrastructure** (`lib/src/actions/show_dialog`,
  `show_sheet`, `show_toast`). Action *registration* is STAC-specific
  and goes; the body of each presenter (how Forui's overlay APIs are
  invoked) is reusable.
- **Audit findings as anti-patterns.** Don't repeat them:
  - Type action payloads from day one (audit R3).
  - No `dynamic` for content fields (R4 — toast title).
  - State-management strategy *before* the third stateful component
    (R1 — covered by "use Forui's grain" but worth re-stating).
  - `///` doc comments on every public class as you go, not as a
    cleanup pass (R10).
  - Tighten `analysis_options.yaml` from day one (R9).

### 4.3 Suggested handoff artifact: `forui_kit`

Before starting ZeroFlat, harvest §4.1 into a small folder neither
STAC- nor ZeroFlat-specific:

```
forui_kit/
  models/        # field shape per Forui component (no STAC base class)
  mappings/      # model → Forui widget functions (no STAC actions)
  tokens/        # color / typography token vocabulary
  test_utils/    # mock-action and find-by-id helpers
  components.md  # vocabulary doc — also used as the agent skill file (§7)
```

That folder lives wherever — could be a directory in ZeroFlat,
could be a private package consumed by both. The point is that the
*Forui knowledge* is decoupled from *which renderer consumes it*.

### 4.4 What to leave behind

- `StacParser` / `StacRegistry` plumbing.
- `json_serializable` codegen — fbs replaces it.
- `_parseOptional`-style nullable-Map helpers — fbs is typed.
- Most of `documents/flatbuffers_strategy.md`. The §6 schema design
  principles (tables, unions, enums, schema-evolution rules) port
  directly to ZeroFlat. The §5 "integrate with STAC parser registry"
  discussion is moot — ZeroFlat owns the registry.

---

## 5. Suggested sequencing

Not a commitment; a strawman to argue with.

### Phase 0 — Don't abandon `stac-forui-components` yet

- **Land token theming (RT1–RT7).** Token vocabulary becomes the
  contract shared with ZeroFlat. Cheaper to do once.
- **Harvest §4.1 into `forui_kit/`** (or wherever). Source of truth
  for Forui knowledge.
- **Decide:** does `stac-forui-components` continue receiving updates
  after ZeroFlat starts, or is it frozen at "demonstration of the
  approach we tried"? Either is defensible; just decide.

### Phase 1 — ZeroFlat skeleton (week 1–2)

- Schema repo / directory: `tokens.fbs`, `actions.fbs`,
  `components.fbs` (one component, Button) and a `StacRoot` table.
- Codegen pipeline: `flatc --rust --dart` from `.fbs`.
- Rinf channel carrying `UIMessage` (fbs) Rust→Dart and
  `FieldUpdate` Dart→Rust.
- Renderer: registry + dispatcher + recursive walk for one component.
- File-watcher hot-reload (§3.2).

### Phase 2 — Components + actions (week 3–4)

- Add the ~15 components. Per component: schema entry, Rust mapping
  (if any), Dart renderer, test, skill-file entry.
- Action union: `ActionNavigate`, `ActionShowDialog`,
  `ActionShowSheet`, `ActionShowToast`, `ActionUpdateState`.
- Form-handling loop (proposal §1): controllers emit field updates
  to Rust; Rust runs Conduit; Rust emits `Patch[]` deltas back.

### Phase 3 — Theming + Lens (week 5–6)

- Port token vocabulary; `ValueNotifier<Palette>` + `FTheme` rebuild.
- Lens overlay: ID-readout on long-press, current-screen fbs dump,
  command bar that writes to the file-watcher target.
- Patrol integration tests using `ValueKey(id)` finders.

### Phase 4 — Defer until the design session (week 7+)

- CRDT/RDF state.
- Iroh peer sync.
- Homebase OTA channel + signing.
- ZK security pieces.

This is **6 focused weeks for v1**, not 3. The 3-week estimate in the
proposal is achievable for "renderer renders a button" but not for
"v1 of the app I'd actually use." Padding goes mostly into the
delta protocol (§3.1) and the schema-evolution discipline (§3.3).

---

## 6. Bottom line

- **Direction:** viable. The local-first / Rust-canonical / fbs-on-the-
  wire / Forui-renderer architecture coheres given your constraints.
- **Strongest case for it:** sensors + iroh + homebase OTA make fbs
  not just defensible but the right pre-investment. The "AI age makes
  own-the-renderer cheaper" argument applies cleanly when the renderer
  is genuinely small (~15 components).
- **Surviving concerns are mechanism-shaped, not direction-shaped:**
  delta protocol shape (§3.1), hot-reload carrier (§3.2), schema-as-
  artifact discipline (§3.3). All three are pinned within phase 1
  or are explicitly deferred to the design session.
- **Reuse:** harvest §4.1 into `forui_kit/` regardless of which path.
  That's ~80% of the 2-week build distilled to portable form.
- **Sequencing:** finish token theming in this repo, harvest, *then*
  start ZeroFlat. Don't fork the codebase mid-token-migration.

## 7. Immediate next steps

Things I can do once you confirm the direction:

1. **Skill file for this repo** (`forui_kit/components.md` or similar)
   — the component vocabulary as a structured doc the agent reads
   when authoring fbs. Will also serve as a `pub.dev` consumer doc
   if `stac-forui-components` ever ships. Format proposal: per-
   component section with schema fields, allowed enum values, Forui
   widget mapped to, and a minimal example fbs/JSON.
2. **Medulla migration plan** — separate workstream. I'll dig into
   the medulla repo, sketch the schema/import path from the current
   `.beads/issues.jsonl`, and propose a migration. Treat as its own
   doc, not part of this one.
3. **Revise this doc** based on the upcoming CRDT/RDF/ZK design session
   (specifically §3.1 and §3.5).

If any of the §3 concerns or the §5 sequencing miss the mark, push
back before we move to phase 0 work.
