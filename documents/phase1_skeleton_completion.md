---
title: Phase 1 Skeleton Completion & Architectural Pivot
date: 2026-05-05
author: Gemini CLI
status: Completion of Phase 1; establishes the "Registry" pattern.
related: phase0_build_handoff.md, integrated_architecture_v2.md
---

# Phase 1 Skeleton Completion & Architectural Pivot

This handoff captures the completion of Phase 1 (Skeleton) and a significant architectural shift that ensures the library is decoupled from any specific UI framework.

---

## 1. Architectural Pivot: The Registry Pattern

Originally envisioned as a static switch-based renderer, `zeroflat` has been refactored into a **Decoupled Engine**.

### The Core Engine (`lib/src/renderer.dart`)
- **"Dumb" Logic**: The `ZeroFlatRenderer` no longer has hardcoded knowledge of Forui or any other widget library.
- **Registry**: It maintains a `Map<StacNodeTypeId, ZeroFlatNodeBuilder>` where builders are registered at runtime.
- **Signal Loop**: It manages the Rinf `UiUpdate` stream, decodes the `StacRoot` FlatBuffer, and dispatches to the registered builders.

### The Accessory Pattern (`lib/src/forui.dart`)
- **`ZeroFlatForui`**: A plugin-style class that registers the standard set of Forui component builders into the engine.
- **Decoupling**: This allows `zeroflat` to remain extremely small (~100 LOC) while the "Look and Feel" lives in separate, optional accessory files.

---

## 2. Completed Work

### Bridge & Signals
- **`native/hub`**: Initialized as a Rinf message hub crate.
- **Signals**: Defined `UiUpdate` (Rust -> Dart) and `UiAction` (Dart -> Rust) as binary signals to carry FlatBuffer payloads.
- **Bindings**: Rinf Dart bindings generated in `lib/src/bindings/`.

### Dispatcher Core
- **`ZeroFlatRenderer`**: Implemented with `StreamBuilder` and recursive `buildNode` logic.
- **`NodeSlot` support**: Helper for unwrapping the vector-of-unions wrapper.

### Skeleton Builders (Forui)
- **`ThemeBuilder`**: Maps to `FTheme` with primary/dark support.
- **`ScaffoldBuilder`**: Maps to `FScaffold` with header/footer/content slots.
- **`ButtonBuilder`**: Maps to `FButton` with full variant and size support.

---

## 3. The "Return Path" (Action Dispatcher)

The `ZeroFlatActionDispatcher` is the next focus. It is designed to be the central point for catching user interactions and sending them back to Rust.

**Status:** Completed. Fully implements FlatBuffer serialization for `StacAction` payloads, wrapping them in a `UiActionEnvelope` before sending via Rinf. Supports `ActionUpdateState`, `ActionNavigate`, `ActionCustom`, and overlay echo-backs.

---

## 4. Environment & Tooling
- **Analysis Cleaned**: `analysis_options.yaml` updated to exclude `lib/src/generated/` from linting (silencing 150+ warnings).
- **Dependencies**: Added `tuple ^2.0.2` (required by Rinf bindings).
- **Barrel File**: `lib/zeroflat.dart` now exports the `Renderer` and the `Forui` accessory.

---

## 5. Next Steps

1.  **Complete Action Dispatcher**: Implement `fbs` serialization in `lib/src/action_dispatcher.dart`.
2.  **Phase 2 (The Harvest)**: Port the remaining ~25 Forui component builders using the new registry pattern.
3.  **App Integration**: Verify the library in a real app with a minimal Rust projector.
