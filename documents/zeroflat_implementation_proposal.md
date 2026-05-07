# Proposal: ZeroFlat Flutter Renderer Implementation

This proposal outlines the implementation plan for the ZeroFlat Flutter library, focusing on a stateless, high-performance rendering architecture that leverages prior work from `stac-forui-components`.

## 1. Architecture: The "Stateless Loop"

The Flutter side operates as a pure function: `f(FlatBufferTree, LocalTheme) -> WidgetTree`.

1.  **Receive:** Rust sends a `StacRoot` FlatBuffer via Rinf.
2.  **Dispatch:** A central `ZeroFlatRenderer` walks the tree.
3.  **Build:** Modular "Component Builders" (the harvested logic) create Forui widgets.
4.  **Action:** User interactions are sent back via a central `ActionDispatcher`.

## 2. Core Components (Dart)

### 2.1 The Central Renderer
This replaces the dynamic `Stac.fromJson` registry with a static, type-safe switch.

```dart
// lib/src/renderer.dart
import 'package:flutter/widgets.dart';
import 'package:zeroflat/src/generated/ui_generated.dart'; // FlatBuffer bindings
import 'builders/button_builder.dart';
import 'builders/scaffold_builder.dart';

class ZeroFlatRenderer extends StatelessWidget {
  final StacNode node;

  const ZeroFlatRenderer({required this.node, super.key});

  @override
  Widget build(BuildContext context) {
    return buildNode(context, node);
  }

  static Widget buildNode(BuildContext context, StacNode? node) {
    if (node == null) return const SizedBox.shrink();

    return switch (node.type) {
      StacNodeType.Scaffold => ScaffoldBuilder.build(context, node.scaffold()!),
      StacNodeType.Button => ButtonBuilder.build(context, node.button()!),
      StacNodeType.TextField => TextFieldBuilder.build(context, node.textField()!),
      // ... all ~15 components
      _ => const SizedBox.shrink(),
    };
  }
}
```

### 2.2 Modular Component Builders (Harvested Logic)
Each builder is a pure static class.

```dart
// lib/src/builders/button_builder.dart
class ButtonBuilder {
  static Widget build(BuildContext context, StacButton model) {
    return FButton(
      key: ValueKey(model.id),
      variant: _mapVariant(model.variant),
      size: _mapSize(model.size),
      onPress: () => ActionDispatcher.dispatch(model.onPress),
      label: model.label != null ? Text(model.label!) : ZeroFlatRenderer.buildNode(context, model.child),
    );
  }

  static FButtonVariant _mapVariant(StacButtonVariant v) {
    return switch (v) {
      StacButtonVariant.Primary => FButtonVariant.primary,
      StacButtonVariant.Secondary => FButtonVariant.secondary,
      StacButtonVariant.Destructive => FButtonVariant.destructive,
      _ => FButtonVariant.outline,
    };
  }
}
```

### 2.3 The Hybrid Theme Registry
Maps semantic tokens from Rust to local `FThemeData`.

```dart
// lib/src/theme_registry.dart
class ThemeRegistry {
  static final Map<String, FThemeData> _themes = {
    'default_light': FThemes.light,
    'default_dark': FThemes.dark,
  };

  static FThemeData get(String id) => _themes[id] ?? FThemes.light;

  // Allows Rust to push "custom" palettes via Rinf
  static void register(String id, FThemeData data) {
    _themes[id] = data;
  }
}
```

### 2.4 The Action Dispatcher
The bridge to Rinf.

```dart
// lib/src/action_dispatcher.dart
class ActionDispatcher {
  static void dispatch(StacAction? action) {
    if (action == null) return;

    // Convert FlatBuffer model to Rinf Signal
    final signal = UiActionSignal(
      id: action.id,
      type: action.type.name,
      payload: action.payload, // Opaque JSON for custom data
    );

    // Rinf auto-generated sender
    sendUiAction(signal);
  }
}
```

## 3. The Rust Side (The "Projector")

Rust doesn't just send raw data; it "projects" the data into the UI vocabulary.

```rust
// rust/src/projector.rs
pub fn project_form(form: &Form) -> StacRoot {
    let mut builder = FlatBufferBuilder::new();
    
    let scaffold = StacScaffold::create(&mut builder, &StacScaffoldArgs {
        id: Some(builder.create_string("main_form")),
        header: Some(project_header(form)),
        content: Some(project_fields(form)),
        ..Default::default()
    });

    // ... wrap and build the final FlatBuffer
}
```

## 4. Implementation Strategy

### Phase 1: The Skeleton
- Setup Rinf with FlatBuffer support.
- Implement the `ZeroFlatRenderer` and the first 3 builders (`Theme`, `Scaffold`, `Button`).
- Verify the "Rust -> Dart" tree delivery and "Dart -> Rust" button click.

### Phase 2: The Harvest
- Port the ~12 remaining component builders from `stac-forui-components`.
- Implement the `ActionDispatcher` with debouncing for `TextFields`.
- Wire up the `ThemeRegistry` with a set of default Forui palettes.

### Phase 3: The Validation
- Build a "Login" and "Settings" screen entirely in Rust.
- Use Patrol for end-to-end testing using the stable `id` keys.

## 5. Why this works
- **Speed:** FlatBuffers and static switches are O(1).
- **Maintainability:** The renderer is "dumb." If you need to change the logic of a form, you edit Rust.
- **Consistency:** By harvesting from `stac-forui-components`, we ensure that the Forui implementation is already tested and refined.

---

**Does this implementation plan align with your vision? If so, I will proceed to create the beads epics and tasks.**
