---
title: zeroflat_svg Companion Package — Implementation Guide
date: 2026-05-11
status: READY TO IMPLEMENT
covers: Svg schema type, full_svg_flutter integration, server-driven playback control
---

# zeroflat_svg Companion Package — Implementation Guide

This document is the implementation reference for `zeroflat_svg` — the companion package
that renders the `Svg` FlatBuffer node using `full_svg_flutter`.

---

## 1. Context

The `Svg` node was added to `schema/zeroflat.fbs` on 2026-05-11. Run `just codegen` first
to regenerate the Dart and Rust bindings before starting the package.

**Schema types added:**

```flatbuffers
enum SvgSourceType : ubyte { Asset = 0, Network, String, Memory }
enum BoxFit        : ubyte { Contain = 0, Cover, Fill, FitWidth, FitHeight, None, ScaleDown }

table Svg {
  id:string (required);
  source:string (required);    // asset path, URL, raw SVG string, or memory key
  source_type:SvgSourceType = Asset;
  width:float;                 // 0.0 = unconstrained
  height:float;                // 0.0 = unconstrained
  fit:BoxFit = Contain;
  auto_play:bool = true;
  loop:bool = true;
  playback_rate:float = 1.0;
}
```

`Svg` is a member of `StacNode` — it renders anywhere a node slot accepts a child.

---

## 2. Package setup

Create `packages/zeroflat_svg/` mirroring the existing `zeroflat_forui` structure.

**`packages/zeroflat_svg/pubspec.yaml`**

```yaml
name: zeroflat_svg
description: Animated SVG support for ZeroFlat via full_svg_flutter.
version: 0.0.1

environment:
  sdk: ^3.11.4
  flutter: ">=1.17.0"

dependencies:
  flutter:
    sdk: flutter
  zeroflat:
    path: ../../          # path dep — points to the core package
  full_svg_flutter: ^1.1.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

> **Note:** The pub.dev package name is `full_svg_flutter` — the GitHub repo is named
> `flutter_full_svg_support` but these differ. Use the pub name in pubspec.yaml.
> Pin to `^1.1.1` — the library is new (May 2026) and still stabilising. Absorb patch
> bumps freely but treat minor bumps as needing review.

---

## 3. File layout

```
packages/zeroflat_svg/
  lib/
    zeroflat_svg.dart           ← public barrel + ZeroFlatSvg.register()
    src/
      svg_builder.dart          ← SvgBuilder.build()
      svg_controller_cache.dart ← AnimatedSvgController lifecycle management
```

---

## 4. BoxFit mapping helper

`fbs.BoxFit` → Flutter's `BoxFit`. Put this in `svg_builder.dart`.

```dart
BoxFit _toFlutterBoxFit(fbs.BoxFit? fit) => switch (fit) {
  fbs.BoxFit.Cover     => BoxFit.cover,
  fbs.BoxFit.Fill      => BoxFit.fill,
  fbs.BoxFit.FitWidth  => BoxFit.fitWidth,
  fbs.BoxFit.FitHeight => BoxFit.fitHeight,
  fbs.BoxFit.None      => BoxFit.none,
  fbs.BoxFit.ScaleDown => BoxFit.scaleDown,
  _                    => BoxFit.contain,
};
```

---

## 5. SvgBuilder

```dart
import 'package:flutter/widgets.dart';
import 'package:full_svg_flutter/full_svg_flutter.dart';
import 'package:zeroflat/src/fbs.dart' as fbs;
import 'svg_controller_cache.dart';

class SvgBuilder {
  static Widget build(BuildContext context, fbs.Svg model) {
    final id = model.id;
    final source = model.source;
    final w = model.width == 0.0 ? null : model.width?.toDouble();
    final h = model.height == 0.0 ? null : model.height?.toDouble();
    final fit = _toFlutterBoxFit(model.fit);

    // Controllers are cached by id so re-renders don't recreate them.
    final controller = SvgControllerCache.acquire(id);

    final widget = switch (model.sourceType) {
      fbs.SvgSourceType.Network => FSvgPicture.network(
          source,
          width: w, height: h, fit: fit,
          controller: controller,
        ),
      fbs.SvgSourceType.String => FSvgPicture.string(
          source,
          width: w, height: h, fit: fit,
          controller: controller,
        ),
      fbs.SvgSourceType.Memory => FSvgPicture.memory(
          // source is a key into an app-level byte cache — see note below
          SvgControllerCache.memoryBytes(source)!,
          width: w, height: h, fit: fit,
          controller: controller,
        ),
      _ => FSvgPicture.asset(
          source,
          width: w, height: h, fit: fit,
          controller: controller,
        ),
    };

    // Apply playback settings after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (model.autoPlay ?? true) {
        controller.play();
      } else {
        controller.pause();
      }
      // playback_rate is not yet exposed in AnimatedSvgController public API —
      // check full_svg_flutter release notes when implementing.
    });

    return SizedBox(
      key: id != null ? ValueKey(id) : null,
      width: w, height: h,
      child: widget,
    );
  }
}
```

> **Memory source note:** `SvgSourceType.Memory` is intended for SVG bytes already
> resident in Dart (e.g. loaded from a bundle or a prior network fetch). You'll need
> a thin app-level registry (`Map<String, Uint8List>`) keyed by the `source` string.
> Add `SvgControllerCache.registerMemory(key, bytes)` when populating it.

---

## 6. Controller cache

`AnimatedSvgController` is stateful — it must survive re-renders of the same logical
component. Cache by `id` and dispose when the component is removed.

```dart
import 'package:full_svg_flutter/full_svg_flutter.dart';

class SvgControllerCache {
  SvgControllerCache._();

  static final Map<String, AnimatedSvgController> _controllers = {};
  static final Map<String, Uint8List> _memoryBytes = {};

  static AnimatedSvgController acquire(String? id) {
    if (id == null) return AnimatedSvgController();
    return _controllers.putIfAbsent(id, AnimatedSvgController.new);
  }

  static void release(String id) {
    _controllers.remove(id)?.dispose();
  }

  static void registerMemory(String key, Uint8List bytes) {
    _memoryBytes[key] = bytes;
  }

  static Uint8List? memoryBytes(String key) => _memoryBytes[key];
}
```

Call `SvgControllerCache.release(id)` when a component with a known id is removed from
the tree. A good hook is a `StatefulWidget` wrapper that calls `release` in `dispose()`.

---

## 7. Server-driven playback control (future schema work needed)

To let Rust pause/resume/seek an SVG, add an action to the schema:

```flatbuffers
// Add to schema/zeroflat.fbs when ready:
enum SvgPlaybackCommand : ubyte { Play = 0, Pause, Stop }

table ActionSvgControl {
  svg_id: string (required);
  command: SvgPlaybackCommand = Play;
  seek_ms: uint;   // only used when command = Play with a seek position
}

// Add ActionSvgControl to union StacAction { ... }
```

Then handle it in `ZeroFlatActionDispatcher` — look up the controller by `svg_id` in
`SvgControllerCache` and call `play()` / `pause()` / `seekTo()`.

This is omitted from the initial schema to keep scope tight — add it when you have a
concrete use case (e.g. stopping a loading spinner when a Rust operation completes).

---

## 8. Registration

```dart
// packages/zeroflat_svg/lib/zeroflat_svg.dart

import 'package:zeroflat/src/fbs.dart' as fbs;
import 'package:zeroflat/src/renderer.dart';
import 'src/svg_builder.dart';

class ZeroFlatSvg {
  static void register() {
    ZeroFlatRenderer.register(
      fbs.StacNodeTypeId.Svg,
      (ctx, m) => SvgBuilder.build(ctx, m as fbs.Svg),
    );
  }
}
```

Call `ZeroFlatSvg.register()` at app startup alongside `ZeroFlatForui.register()`.

---

## 9. Rust side — sending an Svg node

```rust
// Static asset — path relative to Flutter assets
let svg = SvgBuilder::new()
    .id("loading-spinner")
    .source("assets/spinner.svg")
    // source_type defaults to Asset
    // auto_play / loop / playback_rate all default to true/true/1.0
    .build(&mut fbb);

// Network SVG
let svg = SvgBuilder::new()
    .id("hero-animation")
    .source("https://example.com/hero.svg")
    .source_type(SvgSourceType::Network)
    .width(320.0)
    .height(240.0)
    .build(&mut fbb);

// Raw SVG string (server generates the SVG dynamically)
let svg = SvgBuilder::new()
    .id("dynamic-chart")
    .source(&generated_svg_string)
    .source_type(SvgSourceType::String)
    .build(&mut fbb);
```

---

## 10. Known caveats (as of 2026-05-11)

| Issue | Status |
|---|---|
| Windows local image loading fails (#13) | Open, no fix yet — test on Windows before shipping |
| `playback_rate` API availability | Verify against full_svg_flutter release notes — may not be in public API yet |
| `<foreignObject>` not rendered | By design — not fixable |
| Complex RTL text | Minor divergence from browsers in edge cases |
| No production track record | Library is ~2 weeks old — pin to exact version, watch for patch releases |

---

## 11. Justfile additions

```just
# Install svg package deps
deps-svg:
  flutter pub get --directory packages/zeroflat_svg

# Run svg package tests
test-svg:
  flutter test packages/zeroflat_svg
```

Add `deps-svg` to the `deps` target and `test-svg` to `test-dart` when the package exists.
