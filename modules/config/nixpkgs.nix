{
  delib,
  inputs,
  ...
}: let
  # Security pin ahead of nixos-unstable (October 21, 2026). Remove it once the
  # pinned nixpkgs carries the fixed version.
  #
  # Node.js October 21 security release (Brotli decoder RCE, TLS hostname
  # bypasses): 24.22.1 is only in nixpkgs staging.
  overlay = _: prev: let
    nodejsPin = node: version: hash:
      node.overrideAttrs (_: {
        inherit version;
        src = prev.fetchurl {
          url = "https://nodejs.org/dist/v${version}/node-v${version}.tar.xz";
          inherit hash;
        };
      });
  in {
    local = rec {
      nodejs_24 = nodejsPin prev.nodejs_24 "24.22.1" "sha256-T1N5eWKAza6wwvNY/QS2oWzE+336g7WoyRqdljtDUjE=";

      wrapper-v2 = prev.callPackage ../../pkgs/wrapper-v2/package.nix {};
      cobalt = prev.callPackage ../../pkgs/cobalt/package.nix {nodejs = nodejs_24;};
      jellyfin = prev.callPackage ../../pkgs/jellyfin/package.nix {
        inherit inputs;
        pkgs = prev;
      };
      jellyfin-animated-artwork = prev.callPackage ../../pkgs/jellyfin-animated-artwork/package.nix {};
      lidarr = prev.callPackage ../../pkgs/lidarr/package.nix {};
      lidarr-gamdl-bridge = prev.callPackage ../../pkgs/lidarr-gamdl-bridge/package.nix {};
      lidarr-plugin-slskd = prev.callPackage ../../pkgs/lidarr-plugin-slskd/package.nix {};
      rip2 = prev.callPackage ../../pkgs/rip2/package.nix {};
      slskd = prev.callPackage ../../pkgs/slskd/package.nix {};
      stalwart = prev.callPackage ../../pkgs/stalwart/package.nix {};
      stalwart-cli = prev.callPackage ../../pkgs/stalwart-cli/package.nix {};
      tailrpproxy = prev.callPackage ../../pkgs/tailrpproxy/package.nix {};
      trmnl-panels = prev.callPackage ../../pkgs/trmnl-panels/package.nix {};
      visor-bootmanager = prev.callPackage ../../pkgs/visor-bootmanager/package.nix {};
      # The zen kernel has no legacy iptables backend; Waydroid's network
      # script needs its nftables variant.
      waydroid-nvidia = prev.callPackage ../../pkgs/waydroid-nvidia/package.nix {
        waydroid = prev.waydroid-nftables;
      };
    };
  };
in
  delib.module {
    name = "nixpkgs";

    nixos.always.nixpkgs = {
      config.allowUnfree = true;
      overlays = [overlay];
    };

    darwin.always.nixpkgs = {
      config.allowUnfree = true;
      overlays = [overlay];
    };
  }
