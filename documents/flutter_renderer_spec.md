# ZeroFlat — Flutter Renderer Specification

## 1. Scope & Responsibility

ZeroFlat Flutter is a **stateless renderer**. It exists solely to turn
structured UI definitions (from Rust) into interactive widgets (using
Forui).

### 1.1 What it DOES
- **Decode:** Deserializes FlatBuffer payloads from the Rinf bridge.
- **Map:** Converts semantic UI nodes (e.g., `StacButton`) into Forui
  widgets (`FButton`).
- **Layout:** Walks the tree and builds the Flutter widget hierarchy.
- **Interactions:** Binds user events (onTap, onChanged) to Rinf signals.
- **Theming:** Applies the token-based theme provided by the core.

### 1.2 What it DOES NOT DO
- **Store State:** It does not own the canonical state of any form or
  field. It only holds transient state (e.g., the current text in a
  controller before it is emitted to Rust).
- **Run Business Logic:** It does not validate fields, calculate
  dependencies, or trigger workflows. It merely reports user actions.
- **Manage Data:** It has no access to GuardianDB, P2P sync, or the
  file system.
- **Orchestrate Navigation:** While it can trigger a "Navigate" action,
  the actual routing and screen content are decided by the Rust core.

## 2. Leveraging Prior Work

ZeroFlat inherits the **Component Vocabulary** and **Mapping Logic**
from the `stac-forui-components` project, but removes the "STAC"
plumbing (JSON, dynamic registries, generic parsers) in favor of a
fixed, typed FlatBuffer contract.

### 2.1 Reusable Logic (The "Forui Mapping")
The core value being migrated is the "how-to" of Forui:
- **Enum Mappings:** `StacForuiButtonStyle` -> `FButtonVariant`.
- **Slot Handling:** How a `Header` maps `suffixes` and `actions` into
  Forui slots.
- **Controller Glue:** How to attach an `FTextFieldController` to an
  action emitter.

### 2.2 Reusable Vocabulary
The list of ~15 components and their fields (defined in `components.md`)
is the same as the Forui mapping work done in the prior project.

## 3. The Rinf Seam

The bridge carries two types of signals:

| Direction | Type | Payload |
|---|---|---|
| Rust -> Dart | `UiUpdate` | A `StacRoot` FlatBuffer tree. |
| Dart -> Rust | `UiAction` | A `StacAction` FlatBuffer (Update, Navigate, etc.). |

### 3.1 The "Local Controller" Rule
To ensure responsiveness, the Flutter renderer uses local controllers
for text input. It does NOT wait for a Rust round-trip on every
keystroke. Instead:
1. User types "A".
2. Local controller updates; `onChanged` fires.
3. Flutter debounces (optional) and sends "A" to Rust.
4. Rust updates state, runs rules, and eventually sends back a delta if
   needed.

## 4. Implementation Strategy

1. **Codegen:** Generate Dart bindings from `.fbs` schema.
2. **Registry:** A simple `switch` or `Map` that looks up the renderer
   for each `StacNode` variant.
3. **Recursive Build:** A `buildNode(StacNode)` function that handles
   the tree traversal.
4. **Action Dispatcher:** A central place to handle `StacAction`
   conversions into Rinf signals.

This approach keeps the Flutter side "dumb" and extremely fast,
fulfilling the "Zero logic frontend" goal.
