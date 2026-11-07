{
  delib,
  pkgs,
  ...
}: let
  stateDir = "/scratch/t3-ci";
  disk = "${stateDir}/system.qcow2";
  seed = "${stateDir}/seed.img";
  agentSocket = "${stateDir}/agent.sock";
  shutdown = pkgs.writeShellScript "t3-ci-shutdown" ''
    printf '%s\n' '{"execute":"guest-shutdown","arguments":{"mode":"powerdown"}}' \
      | ${pkgs.coreutils}/bin/timeout 5 ${pkgs.socat}/bin/socat - UNIX-CONNECT:${agentSocket} \
      > /dev/null 2>&1 || true
    for attempt in {1..110}; do
      kill -0 "$MAINPID" 2>/dev/null || exit 0
      ${pkgs.coreutils}/bin/sleep 1
    done
  '';
in
  delib.module {
    name = "argo";

    nixos.ifEnabled = {
      users.groups.t3-ci = {};
      users.users.t3-ci = {
        isSystemUser = true;
        group = "t3-ci";
        extraGroups = ["kvm"];
        home = stateDir;
      };

      environment.etc."t3-ci/user-data".text =
        "#cloud-config\n"
        + builtins.toJSON {
          "hostname" = "argo-ci";
          "manage_etc_hosts" = true;
          "ssh_pwauth" = false;
          "disable_root" = true;
          "users" = [
            {
              "name" = "runner";
              "groups" = ["sudo"];
              "sudo" = "ALL=(ALL) NOPASSWD:ALL";
              "shell" = "/bin/bash";
              "lock_passwd" = true;
            }
          ];
          "package_update" = true;
          "packages" = ["qemu-guest-agent" "ca-certificates" "curl" "git" "jq" "build-essential" "pkg-config" "python3" "unzip" "zip" "xz-utils" "zstd" "file" "rsync" "libicu74" "libssl-dev" "libsecret-1-dev" "libkrb5-3" "libunwind8" "libffi-dev" "openjdk-21-jdk-headless" "ccache" "cmake" "ninja-build" "clang" "lld" "patchelf" "libfuse2t64" "libgtk-3-0t64" "libnss3" "libasound2t64" "libgbm1"];
          "write_files" = [
            {
              "path" = "/usr/local/sbin/t3-ci-bootstrap";
              "permissions" = "0755";
              "content" = builtins.readFile ./t3-ci-bootstrap.sh;
            }
          ];
          "runcmd" = [["systemctl" "enable" "--now" "qemu-guest-agent"] ["/usr/local/sbin/t3-ci-bootstrap"]];
        };
      environment.etc."t3-ci/network-config".text = builtins.toJSON {
        "version" = 2;
        "ethernets" = {
          "ci" = {
            "match" = {"name" = "en*";};
            "dhcp4" = true;
            "dhcp6" = false;
            "dhcp4-overrides" = {"use-dns" = false;};
            "nameservers" = {"addresses" = ["1.1.1.1" "9.9.9.9"];};
          };
        };
      };
      environment.etc."t3-ci/meta-data".text = "instance-id: t3-ci-20261107\nlocal-hostname: argo-ci\n";

      systemd.tmpfiles.rules = [
        "d ${stateDir} 0700 t3-ci t3-ci - -"
      ];

      systemd.services.t3-ci = {
        description = "Isolated Ubuntu build runner for T3 Code";
        wantedBy = ["multi-user.target"];
        wants = ["network-online.target"];
        after = ["network-online.target"];
        unitConfig = {
          ConditionPathExists = [disk seed];
          RequiresMountsFor = [stateDir];
        };
        serviceConfig = {
          Type = "simple";
          User = "t3-ci";
          Group = "t3-ci";
          SupplementaryGroups = ["kvm"];
          WorkingDirectory = stateDir;
          UMask = "0077";
          ExecStart = ''
            ${pkgs.qemu}/bin/qemu-system-x86_64 \
              -name t3-ci -machine q35,accel=kvm -cpu host -smp 6 -m 20480 \
              -drive file=${disk},format=qcow2,if=virtio,discard=unmap \
              -drive file=${seed},format=raw,if=virtio,readonly=on \
              -netdev user,id=ci,ipv6=off \
              -device virtio-net-pci,netdev=ci \
              -device virtio-rng-pci \
              -device virtio-serial-pci \
              -chardev socket,path=${agentSocket},server=on,wait=off,id=qga \
              -device virtserialport,chardev=qga,name=org.qemu.guest_agent.0 \
              -display none -serial stdio -monitor none
          '';
          ExecStop = shutdown;
          Restart = "on-failure";
          RestartSec = 10;
          TimeoutStopSec = 120;
          KillMode = "mixed";
          CPUQuota = "600%";
          CPUWeight = 25;
          MemoryMax = "22G";
          MemorySwapMax = 0;
          IOWeight = 25;
          Nice = 10;
          OOMPolicy = "stop";

          NoNewPrivileges = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          ReadWritePaths = [stateDir];
          PrivateTmp = true;
          PrivateDevices = false;
          DevicePolicy = "closed";
          DeviceAllow = ["/dev/kvm rw"];
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          ProtectClock = true;
          LockPersonality = true;
          RestrictSUIDSGID = true;
          RestrictRealtime = true;
          RestrictNamespaces = true;
          RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK"];
          CapabilityBoundingSet = "";

          # The guest uses public DNS; QEMU's proxy to host-local resolved is blocked.
          IPAddressDeny = [
            "0.0.0.0/8"
            "10.0.0.0/8"
            "100.64.0.0/10"
            "127.0.0.0/8"
            "169.254.0.0/16"
            "172.16.0.0/12"
            "192.168.0.0/16"
            "224.0.0.0/4"
            "::/128"
            "::1/128"
            "fc00::/7"
            "fe80::/10"
            "ff00::/8"
            "37.27.111.236/32"
            "2a01:4f9:3070:2256::2/128"
          ];
        };
      };
    };
  }
