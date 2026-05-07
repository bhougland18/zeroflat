/// zeroflat — stateless Flutter UI renderer engine.
///
/// Turns FlatBuffer trees (StacRoot) received from Rust via Rinf binary signals
/// into widgets. The engine is UI-framework-agnostic: builders for specific
/// component libraries are registered at startup by a companion package.
///
/// Public surface:
///   ZeroFlatRenderer       — top-level widget; mounts on UiUpdate signals
///   ZeroFlatActionDispatcher — serialises user interactions → Rinf → Rust
///   ZeroFlatNodeBuilder    — builder function typedef for registration
///
/// Component library packages (e.g. zeroflat_forui) call:
///   ZeroFlatRenderer.register(type, builder)
///   ZeroFlatActionDispatcher.setOverlayHandler(handler)
library;

export 'src/renderer.dart';
export 'src/action_dispatcher.dart';
