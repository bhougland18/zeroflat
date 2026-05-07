# ZeroFlat — Hybrid Action & Theme Proposal

## 1. Action Dispatcher (Flutter -> Rust)

The `ActionDispatcher` is the outgoing seam. It captures user intent and sends it to the Rust "Brain" for processing.

### 1.1 The Pattern
We use a command-based pattern where the renderer binds events to a central dispatcher.

```dart
class ActionDispatcher {
  static void dispatch(StacAction? action) {
    if (action == null) return;

    // Convert the FlatBuffer action model into a Rinf signal
    final signal = switch (action) {
      StacActionUpdateState a => ActionSignal(
          type: ActionType.updateState,
          key: a.key,
          value: a.value,
        ),
      StacActionNavigate n => ActionSignal(
          type: ActionType.navigate,
          route: n.route,
        ),
      // ... 
    };

    // Send to Rust via Rinf
    sendActionSignal(signal);
  }
}
```

### 1.2 Local Interaction Loop
For inputs (like `TextField`), we don't round-trip on every character.
1. Flutter `TextField` uses a local `TextEditingController`.
2. On `onChanged`, we send a "debounced" or "onBlur" signal to Rust.
3. Rust updates the canonical state in GuardianDB.

---

## 2. Hybrid Theming (Flutter + Rust)

Your intuition is correct: encoding every color hex and border radius in FlatBuffers is brittle and verbose. Instead, we use a **Token-to-Style Mapping** strategy.

### 2.1 The Split
- **Rust (The Intent):** Decides *which* theme is active (e.g., "Default", "High Contrast", "Brand A") and sends semantic **Tokens** (e.g., `primary`, `surface`, `error`).
- **Flutter (The Look):** Maintains a local `ThemeRegistry` that maps those Tokens/Themes to real `FThemeData`.

### 2.2 How it works in Flutter

We create a `ZeroFlatTheme` widget that listens for theme signals from Rust.

```dart
class ZeroFlatTheme extends StatelessWidget {
  final String themeId; // Received from Rust (e.g., 'default_dark')
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Look up the actual Forui theme data locally
    final FThemeData themeData = ThemeRegistry.get(themeId);

    return FTheme(
      data: themeData,
      child: child,
    );
  }
}
```

### 2.3 The Benefits
1.  **Instant Swapping:** Flutter can switch visual styles instantly without re-downloading a UI tree.
2.  **Platform Native:** We can use Flutter-native features like `MediaQuery` or `PlatformBrightness` to tweak the theme locally (e.g., picking the dark variant automatically).
3.  **Low Payload:** Rust just sends a string ID or a few "Overriding Tokens" rather than a 50-field color struct.

### 2.4 "Overriding" via Rust (The Middle Ground)
If Rust *needs* to force a specific color (e.g., a user-picked highlight), it can send an optional `CustomToken`:

```rust
// Rust sends this
ThemeUpdate {
   base_id: "ocean",
   overrides: { "primary": "#FF5500" } 
}
```
Flutter's `ThemeRegistry` merges the `base_id` with the `overrides` to produce the final `FThemeData`.

## 3. Honest Thoughts
This "Hybrid" approach is significantly more robust than "Pure SDUI." 
- **Pure SDUI** feels like a "web browser in a box" and often feels sluggish because it fights the host platform's strengths.
- **Hybrid SDUI** (ZeroFlat) treats Flutter as an **intelligent renderer**. Flutter knows *how* to draw a beautiful `FCard`, and Rust knows *why* that card is there and *what* happens when it's clicked.

**Next Step:** I can create a draft of the `ThemeRegistry` to show how we'd map your existing Forui token knowledge into this hybrid model.
