#!/usr/bin/env bash
set -euo pipefail

workspace_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
flutter_root="${workspace_root}/.cache/flutter-sdk"

prepare_flutter_sdk() {
  local nix_flutter_root
  nix_flutter_root=$(nix develop --command bash -c 'echo $NIX_FLUTTER_SDK' | tail -n 1)

  echo "== Preparing writable Flutter SDK mirror at ${flutter_root} =="

  mkdir -p "$flutter_root"

  for item in "$nix_flutter_root"/*; do
    name=$(basename "$item")
    if [ "$name" == "bin" ]; then
      if [ -e "$flutter_root/bin" ]; then rm -rf "$flutter_root/bin"; fi
      cp -r "$item" "$flutter_root/"
      chmod -R u+w "$flutter_root/bin"
    else
      if [ ! -e "$flutter_root/$name" ]; then
        ln -s "$item" "$flutter_root/$name"
      fi
    fi
  done

  if [ -e "$flutter_root/bin/cache" ]; then
    rm -rf "$flutter_root/bin/cache"
  fi
  mkdir -p "$flutter_root/bin/cache"

  for item in "$nix_flutter_root/bin/cache"/*; do
    ln -s "$item" "$flutter_root/bin/cache/$(basename "$item")"
  done

  if [ -L "$flutter_root/bin/cache/artifacts" ]; then
    echo "== Breaking artifacts symlink =="
    rm "$flutter_root/bin/cache/artifacts"
    mkdir -p "$flutter_root/bin/cache/artifacts"
    for a in "$nix_flutter_root/bin/cache/artifacts"/*; do
      ln -s "$a" "$flutter_root/bin/cache/artifacts/$(basename "$a")"
    done
  fi

  if [ -L "$flutter_root/bin/cache/artifacts/engine" ]; then
    echo "== Breaking engine symlink =="
    rm "$flutter_root/bin/cache/artifacts/engine"
    mkdir -p "$flutter_root/bin/cache/artifacts/engine"
    for e in "$nix_flutter_root/bin/cache/artifacts/engine"/*; do
      ln -s "$e" "$flutter_root/bin/cache/artifacts/engine/$(basename "$e")"
    done
  fi

  if [ -L "$flutter_root/bin/cache/artifacts/engine/linux-x64" ]; then
    echo "== Breaking linux-x64 symlink =="
    rm "$flutter_root/bin/cache/artifacts/engine/linux-x64"
    mkdir -p "$flutter_root/bin/cache/artifacts/engine/linux-x64"
    for l in "$nix_flutter_root/bin/cache/artifacts/engine/linux-x64"/*; do
      ln -s "$l" "$flutter_root/bin/cache/artifacts/engine/linux-x64/$(basename "$l")"
    done
  fi

  echo "== Bootstrap complete. Re-enter the nix shell to pick up the local SDK. =="
}

prepare_flutter_sdk
