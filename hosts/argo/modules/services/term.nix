{
  delib,
  pkgs,
  ...
}: let
  port = 2022;
  ipv4 = "37.27.111.236";
  # A second address from the /64, so the site has an IPv6 port 22 of its own;
  # sshd keeps ::2.
  ipv6 = "2a01:4f9:3070:2256::22";
  chain = "xorwyrm-term";
in
  # term.xorwyrm.sh: `ssh term.xorwyrm.sh` shows xorwyrm.sh in the terminal
  # (pkgs/xorwyrm-ssh). It runs no shell and lets anyone in.
  #
  # It listens on 2022, and new connections to port 22 on the public IPv4 and
  # on ::22 are redirected to it, so sshd never has to move: it keeps port 22
  # on Tailscale and on ::2, and the key-only public fallback still works over
  # IPv6. Only public IPv4 port 22 now goes to the site instead.
  #
  # DNS (Cloudflare, not proxied): term.xorwyrm.sh A 37.27.111.236,
  # AAAA 2a01:4f9:3070:2256::22.
  delib.module {
    name = "argo";

    nixos.ifEnabled = {
      systemd.network.networks."10-uplink".address = ["${ipv6}/64"];

      networking.firewall = {
        # The redirect rewrites the port before the firewall looks, so it sees
        # 2022. Open to anyone, which is the point.
        allowedTCPPorts = [port];
        # Its own nat chain, flushed and refilled, so reloading the firewall
        # doesn't stack copies.
        extraCommands = ''
          iptables -t nat -N ${chain} 2>/dev/null || true
          iptables -t nat -F ${chain}
          iptables -t nat -A ${chain} -d ${ipv4} -p tcp --dport 22 -j REDIRECT --to-ports ${toString port}
          iptables -t nat -C PREROUTING -i enp6s0 -j ${chain} 2>/dev/null || iptables -t nat -A PREROUTING -i enp6s0 -j ${chain}

          ip6tables -t nat -N ${chain} 2>/dev/null || true
          ip6tables -t nat -F ${chain}
          ip6tables -t nat -A ${chain} -d ${ipv6} -p tcp --dport 22 -j REDIRECT --to-ports ${toString port}
          ip6tables -t nat -C PREROUTING -i enp6s0 -j ${chain} 2>/dev/null || ip6tables -t nat -A PREROUTING -i enp6s0 -j ${chain}
        '';
        extraStopCommands = ''
          iptables -t nat -D PREROUTING -i enp6s0 -j ${chain} 2>/dev/null || true
          iptables -t nat -F ${chain} 2>/dev/null || true
          iptables -t nat -X ${chain} 2>/dev/null || true
          ip6tables -t nat -D PREROUTING -i enp6s0 -j ${chain} 2>/dev/null || true
          ip6tables -t nat -F ${chain} 2>/dev/null || true
          ip6tables -t nat -X ${chain} 2>/dev/null || true
        '';
      };

      systemd.services.xorwyrm-term = {
        description = "xorwyrm.sh over ssh (term.xorwyrm.sh)";
        wantedBy = ["multi-user.target"];
        after = ["network-online.target"];
        wants = ["network-online.target"];
        environment = {
          # both IPv4 and IPv6
          XORWYRM_LISTEN = "[::]:${toString port}";
          # made on first start and kept: if it changed, returning visitors
          # would get a host key warning
          XORWYRM_HOST_KEY = "/var/lib/xorwyrm-term/host_key";
        };
        serviceConfig = {
          ExecStart = "${pkgs.local.xorwyrm-ssh}/bin/xorwyrm-ssh";
          Restart = "always";
          RestartSec = 2;
          DynamicUser = true;
          StateDirectory = "xorwyrm-term";
          StateDirectoryMode = "0700";

          # It only needs to listen and draw.
          CapabilityBoundingSet = "";
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          ProtectClock = true;
          ProtectHostname = true;
          ProtectProc = "invisible";
          ProcSubset = "pid";
          RestrictAddressFamilies = ["AF_INET" "AF_INET6"];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          SystemCallArchitectures = "native";
          SystemCallFilter = ["@system-service" "~@privileged" "~@resources"];
          UMask = "0077";
          # 200 visitors at most (its own limit) fit well inside these.
          MemoryMax = "1G";
          CPUQuota = "200%";
          TasksMax = 64;
        };
      };
    };
  }
