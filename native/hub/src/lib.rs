use rinf::{DartSignalBinary, RustSignalBinary};
use serde::{Deserialize, Serialize};

mod mocks;

/// Signal from Rust to Dart carrying a StacRoot FlatBuffer.
#[derive(Serialize, RustSignalBinary)]
pub struct UiUpdate;

/// Signal from Dart to Rust carrying a UiActionEnvelope FlatBuffer.
#[derive(Deserialize, DartSignalBinary)]
pub struct UiAction;

pub async fn main() {
    // Send the login screen on startup so the Flutter renderer has something to display.
    let bytes = mocks::login_view::build();
    UiUpdate.send_signal_to_dart(bytes);

    // Listen for actions from Dart and log them (routing TBD when Conduit is wired).
    let mut receiver = UiAction::get_dart_signal_receiver();
    while let Some(signal) = receiver.recv().await {
        let _ = signal; // placeholder — Conduit dispatch goes here
    }
}
