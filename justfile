default:
  @just --list

# Run flatc codegen for all .fbs files → Dart and Rust
codegen:
  @echo "== Generating Dart FlatBuffer bindings =="
  flatc --dart -o lib/src/generated schema/*.fbs
  @echo "== Generating Rust FlatBuffer bindings =="
  flatc --rust -o native/src/generated schema/*.fbs
  @echo "== Codegen complete =="

# Install Dart/Flutter dependencies for all packages
deps:
  flutter pub get
  flutter pub get --directory packages/zeroflat_forui

# Check Rust workspace
check:
  cargo check --workspace

# Run Rust tests
test-rust:
  cargo test --workspace

# Run Flutter tests (all packages)
test-dart:
  flutter test
  flutter test packages/zeroflat_forui

# Run Patrol integration tests on Linux desktop (no emulator needed)
# First-time setup: dart pub global activate patrol_cli
test-integration:
  patrol test -d linux integration_test/stable_ids_test.dart

# Run all tests
test: test-rust test-dart

# Format all code
fmt:
  cargo fmt --all
  dart format lib/ test/
  dart format packages/zeroflat_forui/lib/ packages/zeroflat_forui/test/ 2>/dev/null || true

# Analyze all Dart packages
analyze:
  flutter analyze
  flutter analyze packages/zeroflat_forui
