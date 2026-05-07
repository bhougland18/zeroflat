---
title: Phase 2 Build Handoff
date: 2026-05-07
status: CURRENT
covers: zeroflat-62m (Phase 2 Harvest), zeroflat-d4h (Patrol + Rust mocks), patrol_cli nix packaging
---

# Phase 2 Build Handoff

All `zeroflat-62m` and `zeroflat-d4h` beads are closed. This document is the point-in-time snapshot of what was built.

---

## 1. Repo layout

```
zeroflat/                          ← core package (renderer, dispatcher, FBS barrel)
  lib/src/
    renderer.dart                  ← ZeroFlatRenderer (registry pattern)
    action_dispatcher.dart         ← ZeroFlatActionDispatcher + debounce + overlay hook
    fbs.dart                       ← re-exports generated code as `fbs` alias
  native/hub/src/
    lib.rs                         ← hub entry point; sends login mock on startup
    mocks/
      login_view.rs                ← Login FlatBuffer builder
      settings_view.rs             ← Settings FlatBuffer builder

packages/zeroflat_forui/           ← Forui component library (separate package)
  lib/src/
    theme_registry.dart            ← ZeroFlatThemeRegistry (10 palettes)
    overlays.dart                  ← ForuiOverlayHandler (Dialog, Toast)
    forui.dart                     ← ZeroFlatForui.register() — wires everything
    builders/
      color_token.dart             ← ColorTokenResolver extension
      theme_builder.dart           ← uses ThemeRegistry
      scaffold_builder.dart
      header_builder.dart
      divider_builder.dart
      button_builder.dart
      text_field_builder.dart
      switch_builder.dart
      checkbox_builder.dart
      card_builder.dart
      dialog_builder.dart

integration_test/
  stable_ids_test.dart             ← 3 Patrol tests (login, settings, re-render stability)

~/nix-config/devshells/features/
  flutter-patrol.nix               ← buildDartApplication for patrol_cli 4.3.1
  flutter-patrol-pubspec.lock.json ← 89-dep lock JSON (generated 2026-05-07)
  core.nix                         ← flutter_patrol.enable option added
```

---

## 2. Package boundary

`zeroflat` (core) has **zero Forui dependency**. The overlay hook pattern keeps the separation clean:

```dart
// In zeroflat_forui at startup:
ZeroFlatActionDispatcher.setOverlayHandler(ForuiOverlayHandler.handle);
```

Swapping Forui for shadcn (or mixing) means writing a new package with its own `register()` — the core is untouched.

---

## 3. ThemeRegistry

`ZeroFlatThemeRegistry` in `packages/zeroflat_forui/lib/src/theme_registry.dart`:

- 10 Forui palettes pre-registered: neutral, zinc, slate, blue, green, orange, red, rose, violet, yellow
- `setPalette(name)` — switch the active palette at runtime (e.g. from settings)
- `registerPalette(name, data)` — inject a custom palette
- `resolve(brightness, touch, {borderRadius, borderWidth})` — applies `FStyleDelta` only when fields are non-zero (0.0 = schema default = use palette value)

`ThemeBuilder` calls `ZeroFlatThemeRegistry.resolve(model.brightness, model.touch, borderRadius: model.borderRadius, borderWidth: model.borderWidth)`.

---

## 4. Key implementation patterns

### ValueKey — stable Patrol finders
Every builder does:
```dart
final id = model.id;  // local var required — Dart won't promote getter types
return FWidget(key: id != null ? ValueKey(id) : null, ...);
```

### Optional slots — buildNodeOrNull
`FScaffold.header` and `.footer` are typed `Widget?`. Use:
```dart
header: ZeroFlatRenderer.buildNodeOrNull(context, model.headerType, model.header),
```
This avoids reserving layout space for absent slots.

### Stateful toggles — Switch and Checkbox
Both use a local `bool _value` with `didUpdateWidget` to accept server-driven changes while preserving optimistic local toggles:
```dart
void didUpdateWidget(covariant _SwitchWidget old) {
  super.didUpdateWidget(old);
  if (widget.model.value != old.model.value) {
    setState(() => _value = widget.model.value ?? false);
  }
}
```

### TextField — FTextFieldControl.managed
`initial:` is only applied on first render (when the ValueKey is new). Local edits survive UiUpdates as long as the key is stable:
```dart
control: FTextFieldControl.managed(
  initial: model.value != null ? TextEditingValue(text: model.value!) : null,
  onChange: id != null ? (val) => ZeroFlatActionDispatcher.dispatchTextField(...) : null,
),
```

### ActionDispatcher debounce
`dispatchTextField` keys timers by component id — 300 ms default. For `ActionUpdateState`, the current text is injected into the builder before sending. Other action types fall through to the regular `dispatch`.

### Overlays
`ActionShowDialog` carries pre-serialised `StacRoot` bytes (`dialog_fbs: [ubyte]`), avoiding a circular union dependency. `ForuiOverlayHandler._showDialog` parses those bytes and calls `DialogBuilder.build`.

---

## 5. Rust mock projectors

`native/hub/src/mocks/` contains two FlatBuffer builders using the generated Rust API (bottom-up pattern):

| Mock | Root node | Stable ids |
|------|-----------|------------|
| `login_view` | Scaffold | `login-scaffold`, `login-header`, `login-card`, `email-field`, `signin-btn` |
| `settings_view` | Scaffold | `settings-scaffold`, `settings-header`, `settings-card`, `notifications-switch` |

Hub `main()` sends `login_view::build()` bytes via `UiUpdate` on startup, then enters a receive loop for `UiAction` signals (Conduit dispatch is a placeholder).

**Compile requirement**: `cargo check --workspace` must run inside `nix develop` — the linker is not available outside.

---

## 6. Patrol integration tests

`integration_test/stable_ids_test.dart` — three tests:

1. **Login screen** — pumps the full Login tree, asserts all 5 component ids are found
2. **Settings screen** — pumps the Settings tree, asserts all 4 ids
3. **Re-render stability** — pumps the same tree twice with a changed label; verifies `email-field` key survives

Tests use Dart `*ObjectBuilder` classes to build FlatBuffers in-test. No Rinf bridge is needed — `_TestHost` parses bytes directly via `fbs.StacRoot(bytes)` and calls `ZeroFlatRenderer.buildNode`.

**Run** (inside `nix develop`, after `just deps`):
```bash
just test-integration
# expands to: patrol test -d linux integration_test/stable_ids_test.dart
```

---

## 7. patrol_cli nix packaging

`patrol_cli` is not in nixpkgs. It is built from source using `buildDartApplication`:

- Feature file: `~/nix-config/devshells/features/flutter-patrol.nix`
- Version: **4.3.1** (tag `patrol_cli-v4.3.1`)
- Source hash: `sha256-vCVcp4vgrOoq3cJLzUgfywQRlEvY664RMTqeBpT8geI=`
- Lock JSON: `flutter-patrol-pubspec.lock.json` (89 deps, generated 2026-05-07)
- Enabled in `zeroflat/flake.nix` via `flutter_patrol.enable = true`
- Default in `core.nix`: `false` (opt-in per project)
- **Verified**: `patrol --version` reports `patrol_cli v4.3.1` inside `nix develop`

To update to a new version see the comment block at the top of `flutter-patrol.nix`.

---

## 8. What's not done yet

| Item | Notes |
|------|-------|
| `ActionShowSheet` | Stubbed in `overlays.dart` — `// Sheet routing — future work` |
| `just test-integration` end-to-end | Not run yet; needs `just deps` inside devshell first |
| Conduit dispatch in hub | `UiAction` receive loop is a placeholder |
| Login/Settings mock screens in Dart (consuming app) | `d4h.1`/`.2` closed as Rust-side only; Dart side is `_TestHost` in integration tests |
