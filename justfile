default:
  @just --list

# Run flatc codegen for all .fbs files → Dart and Rust
codegen:
  @echo "== Generating Dart FlatBuffer bindings =="
  flatc --dart -o lib/src/generated schema/*.fbs
  @echo "== Generating Rust FlatBuffer bindings =="
  flatc --rust -o native/src/generated schema/*.fbs
  @echo "== Codegen complete =="

# Check Rust workspace
check:
  cargo check --workspace

# Run Rust tests
test-rust:
  cargo test --workspace

# Run Flutter tests
test-dart:
  flutter test
  flutter test packages/zeroflat_forui

# Run all tests
test: test-rust test-dart

# Build the example app for Linux
build-example:
  cd example && flutter build linux --debug

# Run the example app (requires a device/emulator)
run-example:
  cd example && flutter run

# Format all code
fmt:
  cargo fmt --all
  dart format lib/ test/
  dart format packages/zeroflat_forui/lib/ packages/zeroflat_forui/test/ 2>/dev/null || true

# Analyze all Dart packages
analyze:
  flutter analyze
  flutter analyze packages/zeroflat_forui
