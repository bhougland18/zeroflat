---
title: Phase 0 Build Handoff
date: 2026-05-05
author: Claude (Sonnet 4.6), in dialogue with Ben
status: Point-in-time snapshot — describes work completed 2026-05-04/05
related: flutter_renderer_spec.md, integrated_architecture_v2.md
---

# Phase 0 Build Handoff

Mid-session handoff capturing the exact state of Phase 0 scaffolding. Read alongside `integrated_architecture_v2.md` for architecture context and `flutter_renderer_spec.md` for renderer design.

---

## What was completed

### Dev shell (`flake.nix`)

Uses `flake-parts` + Dendritic devshell feature modules from `~/nix-config/devshells/features/`.

Enabled features: `ai_tools`, `beads`, `direnv`, `flutter`, `jujutsu`, `native_cc`, `rinf`, `rust`, `rust_devtools`, `stac`.
Extra packages: `pkgs.flatbuffers` (v25.12.19), `pkgs.just`.

Fix applied: `ai-tools.nix` updated to use `inputs'` (per-system) instead of `inputs` — flake-parts explicitly blocks `inputs` as a perSystem module arg.

### Flutter package scaffolding

- **`pubspec.yaml`**: `name: zeroflat`; deps = `flutter`, `forui ^0.21.2`, `flat_buffers ^23.5.26`, `rinf ^8.10.0`
- **`lib/zeroflat.dart`**: public barrel — currently just the `library zeroflat;` declaration and docstring. `ZeroFlatRenderer` will be exported here once built.
- **`lib/src/fbs.dart`**: internal barrel — `export 'generated/zeroflat_zeroflat_generated.dart'`. Internal code must import this with `as fbs` to avoid shadowing Flutter's own `Brightness` and `Axis` enums.
- **`scripts/bootstrap-dev-workspace.sh`**: creates writable `.cache/flutter-sdk` mirror (breaks symlinks for `bin/`, `bin/cache/`, `artifacts/`, `engine/`, `linux-x64/`).

### Rust crate

- **`Cargo.toml`** (workspace root): `members = ["native"]`
- **`native/Cargo.toml`**: `name = "zeroflat-fbs"`, dep `flatbuffers = "25.2.10"`
- **`native/src/lib.rs`**: `pub mod generated; pub use generated::zeroflat_generated as fbs;`
- **`native/src/generated/mod.rs`**: `pub mod zeroflat_generated;` — **hand-written**, not flatc output

### FlatBuffers schema (`schema/zeroflat.fbs`)

Codegen runs clean with `just codegen`. Three design decisions worth knowing:

**1. `union StacNode` declared before member tables.**
flatc can forward-reference tables but not unions. Declaration order matters — `union StacNode { ... }` must appear before the component tables that reference it, even though the member tables (Theme, Scaffold, etc.) are defined after.

**2. `NodeSlot` wrapper for vector-of-union fields.**
Dart's flatc codegen does not support `[UnionType]` (vectors of unions). `Header.suffixes`, `Header.actions`, and `Dialog.actions` use `[NodeSlot]` instead of `[StacNode]`. `NodeSlot` is a one-field wrapper table: `table NodeSlot { node:StacNode; }`. When dispatching in the renderer, unwrap via `slot.node`.

**3. Overlay actions carry pre-serialised bytes.**
`ActionShowDialog { dialog_fbs:[ubyte] }` and `ActionShowSheet { side:SheetSide; sheet_fbs:[ubyte] }` carry a complete, pre-serialised `StacRoot` FlatBuffer rather than an inline `StacNode`. This breaks the `StacAction ↔ StacNode` circular union dependency that flatc cannot resolve. In Flutter, decode with `StacRoot.fromBuffer(action.dialogFbs!)` and push the root node through the normal render path as a modal overlay.

### Justfile

```
codegen   → flatc --dart -o lib/src/generated schema/*.fbs
             flatc --rust -o native/src/generated schema/*.fbs
check     → cargo check --workspace
test-rust → cargo test --workspace
test-dart → flutter test
test      → test-rust test-dart
fmt       → cargo fmt --all && dart format lib/ test/
```

### `.gitignore`

Key entries:
- `lib/src/generated/*.dart` — flatc Dart output (gitignored; run `just codegen` after clone)
- `native/src/generated/zeroflat_generated.rs` — flatc Rust output (gitignored)
- `native/src/generated/mod.rs` is **not** ignored (hand-written re-export)
- `.cache/` — writable Flutter SDK mirror
- `pubspec.lock` — library package, lock not committed
- `/target/`

---

## Bead / task structure

Phase 0 — bead ID prefix `7ln`:

| Bead | Description | Status |
|---|---|---|
| `7ln.1` | Scaffold Flutter lib package | done |
| `7ln.5` | FlatBuffers schema + codegen | done |
| `7ln.6` | Dart codegen pipeline wiring (barrel files) | **in_progress** |
| `7ln.7` | Rust codegen pipeline verification | largely done |
| `7ln.2` | Rinf bridge signals (UiUpdate / UiAction) | not started |
| `7ln.3` | ZeroFlatRenderer dispatcher core | not started |
| `7ln.4` | Theme, Scaffold, Button builders | not started |

Phase 2 (component builders) — bead ID prefix `62m`:
`62m.1` TextField · `62m.3–62m.10` Header, Divider, Switch, Checkbox, Card, Dialog, ActionDispatcher, ThemeRegistry

Phase 3 (validation) — bead ID prefix `d4h`:
`d4h.1–d4h.3` Login/Settings mocks + Patrol tests

---

## Known pitfalls

- **`Brightness` / `Axis` name conflicts.** The generated Dart file defines these enums. Any file that imports both Flutter and FlatBuffer types must use `import 'src/fbs.dart' as fbs;` and qualify with `fbs.Brightness`, `fbs.Axis`. Never bare-import the generated file in widget code.

- **Codegen prerequisite.** Generated files are gitignored. Fresh clone requires `just codegen` before `flutter analyze` or `flutter test` will resolve imports.

- **flutter_duit note.** Before implementing `ActionDispatcher` (bead `62m.8`), review [flutter_duit](https://github.com/Duit-Foundation/flutter_duit)'s overlay/action dispatch pattern — there may be patterns worth borrowing.

---

## Next steps

1. Run `flutter analyze` — confirm barrel files (`lib/zeroflat.dart`, `lib/src/fbs.dart`) are clean.
2. Mark `7ln.6` complete.
3. Verify Rust codegen end-to-end: `just codegen && cargo check` → mark `7ln.7` complete.
4. Start `7ln.2` — Rinf bridge signal wiring (UiUpdate Rust→Dart, UiAction Dart→Rust).
