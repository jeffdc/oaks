{
  description = "Oak Compendium development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      # aarch64-darwin: development Macs. x86_64-linux: GitHub Actions runners.
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      # Tailwind is pinned to the version in config/config.exs (nixpkgs has a newer one).
      # Same release the Dockerfile downloads; keep all three in sync.
      tailwindVersion = "4.1.12";
      tailwindAssets = {
        aarch64-darwin = {
          name = "tailwindcss-macos-arm64";
          hash = "sha256-fWm+F3a76KSeFXFNmHPQiVnDIK/w8HFNjY5tnQDZtUM=";
        };
        x86_64-linux = {
          name = "tailwindcss-linux-x64";
          hash = "sha256-Xu7mbqI36umhYPozFP0M92q5k1Uamfr7Fvodtsa5Aok=";
        };
      };
    in
    {
      devShells = forAllSystems (
        pkgs:
        let
          inherit (pkgs) lib stdenv;

          # Elixir/OTP must match the Dockerfile builder image (scripts/check-toolchain).
          beam = pkgs.beam.packages.erlang_28;

          tailwindAsset = tailwindAssets.${stdenv.hostPlatform.system};
          tailwind = pkgs.runCommand "tailwindcss-${tailwindVersion}" { } ''
            install -Dm755 ${
              pkgs.fetchurl {
                url = "https://github.com/tailwindlabs/tailwindcss/releases/download/v${tailwindVersion}/${tailwindAsset.name}";
                inherit (tailwindAsset) hash;
              }
            } $out/bin/tailwindcss
          '';
        in
        {
          default = pkgs.mkShell {
            packages = [
              # On macOS the shell sets DEVELOPER_DIR to Nix's Apple SDK, which breaks
              # /usr/bin/git (an xcrun stub: "tool 'git' not found"). A real git fixes it.
              pkgs.git
              beam.erlang
              beam.elixir_1_19
              # sqlite3 CLI: loads test seeds (make test-db, CI) and inspects oaks.db.
              pkgs.sqlite
              # tofu: manages the AWS resources in infra/ (infra/README.md).
              pkgs.opentofu
              pkgs.pkg-config
            ]
            ++ lib.optionals stdenv.hostPlatform.isLinux [ pkgs.inotify-tools ];

            # vix (the image library's libvips binding) compiles against this
            # libvips through pkg-config. Same as gallformers.
            buildInputs = [ pkgs.vips ];

            env = {
              # OTP >= 28.5.0.6 httpc rejects GitHub's release redirects (headers over
              # 10240 bytes), which breaks vix's download of its precompiled libvips.
              # Build it against the libvips above instead (as the Dockerfile does).
              VIX_COMPILATION_MODE = "PLATFORM_PROVIDED_LIBVIPS";
              # Hand the tailwind package the pinned, hashed binary above, so dev and CI
              # never run its own unverified download (same as gallformers).
              MIX_TAILWIND_PATH = "${tailwind}/bin/tailwindcss";
            };
          };
        }
      );
    };
}
