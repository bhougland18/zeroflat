{
  description = "zeroflat — local-first body-asymmetry / mental-state tracking";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nix-config.url = "path:/home/ben/nix-config";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex.url = "github:sadjow/codex-cli-nix";
    gemini.url = "github:sadjow/gemini-cli-nix";
    claude-code.url = "github:sadjow/claude-code-nix";
    beads.url = "github:gastownhall/beads";
  };

  outputs =
    inputs@{
      flake-parts,
      nixpkgs,
      nix-config,
      fenix,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [
        (nix-config + /devshells/features/core.nix)
        (nix-config + /devshells/features/ai-tools.nix)
        (nix-config + /devshells/features/beads.nix)
        (nix-config + /devshells/features/direnv.nix)
        (nix-config + /devshells/features/flutter.nix)
        (nix-config + /devshells/features/flutter-patrol.nix)
        (nix-config + /devshells/features/jujutsu.nix)
        (nix-config + /devshells/features/native-cc.nix)
        (nix-config + /devshells/features/rinf.nix)
        (nix-config + /devshells/features/rust.nix)
        (nix-config + /devshells/features/rust-devtools.nix)
        (nix-config + /devshells/features/stac.nix)
      ];

      perSystem =
        { system, ... }:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          fenixToolchain = fenix.packages.${system}.stable.withComponents [
            "cargo"
            "clippy"
            "rust-src"
            "rustc"
            "rustfmt"
          ];
          fenixRustSrc = "${fenix.packages.${system}.stable.rust-src}/lib/rustlib/src/rust/library";
        in
        {
          _module.args = {
            inherit pkgs fenixToolchain fenixRustSrc;
          };

          dendritic.devShell = {
            description = "zeroflat development shell";
            packages = [ pkgs.flatbuffers pkgs.just ];

            features = {
              ai_tools.enable = true;
              beads.enable = true;
              direnv.enable = true;
              flutter.enable = true;
              flutter_patrol.enable = true;
              jujutsu.enable = true;
              native_cc.enable = true;
              rinf.enable = true;
              rust.enable = true;
              rust_devtools.enable = true;
              stac.enable = true;

              android.enable = false;
              cargo_polylith.enable = false;
              crane.enable = false;
              rust_lint_dylint.enable = false;
            };
          };
        };
    };
}
