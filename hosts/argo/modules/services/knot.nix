{
  config,
  delib,
  ...
}: let
  hostname = "knot.skulldogged.dev";
  # Locally managed tunnel "argo-knot"; its credentials are in argo-knot.yaml.
  tunnelId = "6354bdcd-529a-42ca-8b46-1b17d57eb1ac";
  stateDir = config.services.tangled.knot-rs.stateDir;
in
  # Mars's Tangled knot (https://tangled.org), holding their git repositories;
  # tangled.org's web app shows them. Its state is the btrfs subvolume mounted
  # at /var/lib/knot (hardware.nix), backed up hourly (backup.nix).
  #
  # Public 443 belongs to Stalwart, so HTTPS comes in through a Cloudflare
  # Tunnel instead. SSH (2222) is reachable over Tailscale only: the tunnel
  # can't carry it, so the git@knot.skulldogged.dev URLs tangled.org shows
  # don't work, and Mars pushes to builder.skate-altair.ts.net:2222 instead.
  delib.module {
    name = "argo";

    nixos.ifEnabled = {
      sops.secrets = {
        # KNOT_MASTER_KEY, which unseals the knot's and every repository's
        # signing keys. Losing it loses control of every repository's identity.
        knot_env.sopsFile = ../../../../secrets/argo-knot.yaml;
        knot_tunnel_credentials.sopsFile = ../../../../secrets/argo-knot.yaml;
      };

      services.tangled.knot-rs = {
        enable = true;
        environmentFile = config.sops.secrets.knot_env.path;
        # Port 2222 stays shut publicly; tailscale0 is a trusted interface.
        openFirewall = false;

        settings = {
          server = {
            inherit hostname;
            admins = ["did:plc:rxomii4zl7qpyu4mryugyrkh"]; # skulldogged.dev
          };
          atproto.plc_directory = "https://plc.directory";
          contact.email = "admin@skulldogged.dev";

          # SHA-1, so repositories can be mirrored to and from GitHub.
          git.object_format = "sha1";

          lfs = {
            store_path = "${stateDir}/lfs";
            # The subvolume shares its filesystem with home and /scratch; keep
            # the headroom fleet jobs need there.
            free_space_floor_bytes = 100 * 1024 * 1024 * 1024;
          };

          # cloudflared connects from loopback and passes on the client's
          # address, which Cloudflare's edge sets and clients can't forge.
          xrpc = {
            trusted_proxy_header = "cf-connecting-ip";
            trusted_proxies = ["127.0.0.1" "::1"];
          };
        };
      };

      systemd.services.knot-rs.unitConfig.RequiresMountsFor = [stateDir];

      services.cloudflared = {
        enable = true;
        tunnels.${tunnelId} = {
          credentialsFile = config.sops.secrets.knot_tunnel_credentials.path;
          ingress.${hostname}.service = "http://127.0.0.1:5555";
          default = "http_status:404";
        };
      };
    };
  }
