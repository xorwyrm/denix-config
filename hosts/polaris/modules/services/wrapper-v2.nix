{
  config,
  delib,
  lib,
  pkgs,
  ...
}:
delib.module {
  name = "polaris";
  nixos.ifEnabled = {
    sops.secrets.wrapper_env = {
      sopsFile = ../../../../secrets/wrapper-v2.yaml;
      restartUnits = ["wrapper-v2.service"];
    };
    users.groups.wrapper-v2 = {};
    users.users.wrapper-v2 = {
      isSystemUser = true;
      group = "wrapper-v2";
      home = "/var/lib/wrapper-v2";
    };
    # A one-time cutover moves the live login state; it never duplicates it.
    systemd.services.wrapper-v2-migrate = {
      description = "Migrate the existing Podman wrapper to native service storage";
      before = ["wrapper-v2.service"];
      unitConfig.ConditionPathExists = "!/var/lib/wrapper-v2/.migrated";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        UMask = "0077";
      };
      path = [pkgs.coreutils pkgs.util-linux pkgs.podman];
      script = ''
        set -eu
        source=/home/marshall/wrapper-v2
        state=/var/lib/wrapper-v2
        data="$state/rootfs/data/data/com.apple.android.music/files"
        if [ ! -f "$source/rootfs/system/bin/linker64" ]; then
          echo "The existing wrapper runtime is missing; refusing migration." >&2
          exit 1
        fi
        if [ -e "$source/data" ] && [ -e "$data" ]; then
          echo "Both old and new login state exist; refusing to overwrite either." >&2
          exit 1
        fi
        if [ ! -d "$source/data" ] && [ ! -d "$data" ]; then
          echo "No existing login state is available; refusing migration." >&2
          exit 1
        fi
        install -d -m 0700 "$state" "$state/runtime/system/lib64" "$state/runtime/system/bin"
        cp -a "$source/rootfs/system/lib64/"*.so "$state/runtime/system/lib64/"
        install -m 0755 "$source/rootfs/system/bin/linker64" "$state/runtime/system/bin/linker64"
        install -d -m 0700 "$state/rootfs/system/bin" "$state/rootfs/system/lib64" \
          "$state/rootfs/etc/ssl/certs" "$state/rootfs/dev" "$state/rootfs/proc" \
          "$state/rootfs/data/data/com.apple.android.music"
        ownerPodman() {
          runuser -u marshall -- env XDG_RUNTIME_DIR=/run/user/1000 ${lib.getExe pkgs.podman} "$@"
        }
        if ownerPodman container exists wrapper-v2; then
          ownerPodman update --restart=no wrapper-v2
          ownerPodman stop --time 30 wrapper-v2
        fi
        if [ -d "$source/data" ]; then
          mv "$source/data" "$data"
        fi
        chown -R wrapper-v2:wrapper-v2 "$state"
        chmod 0700 "$state"
        touch "$state/.migrated"
      '';
    };
    systemd.services.wrapper-v2 = {
      description = "Native Apple Music wrapper supervisor";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target" "wrapper-v2-migrate.service"];
      requires = ["wrapper-v2-migrate.service"];
      unitConfig = {
        StartLimitBurst = 5;
        StartLimitIntervalSec = 300;
      };
      environment = {
        WRAPPER_HOST = "127.0.0.1";
        WRAPPER_PORT = "8080";
        WRAPPER_LAUNCHER = "${pkgs.local.wrapper-v2}/libexec/worker-launch";
        WRAPPER_ROOTFS = "/var/lib/wrapper-v2/rootfs";
        WRAPPER_SESSION_DIR = "/data/data/com.apple.android.music/files";
        # The saved login belongs to the identity the pre-1.0 wrapper used by
        # default. 1.0.0 would otherwise generate a new one for this session.
        WRAPPER_DEVICE_INFO = "Music/4.9/Android/10/Samsung S9/7663313/en-US/en-US/dc28071e981c439e";
        RUST_LOG = "info";
      };
      serviceConfig = {
        User = "wrapper-v2";
        Group = "wrapper-v2";
        StateDirectory = "wrapper-v2";
        StateDirectoryMode = "0700";
        WorkingDirectory = "/var/lib/wrapper-v2";
        ExecStart = lib.getExe pkgs.local.wrapper-v2;
        EnvironmentFile = config.sops.secrets.wrapper_env.path;
        Restart = "on-failure";
        RestartSec = "5s";
        TimeoutStopSec = "30s";
        KillMode = "control-group";
        CapabilityBoundingSet = ["CAP_SYS_ADMIN" "CAP_SYS_CHROOT"];
        AmbientCapabilities = ["CAP_SYS_ADMIN" "CAP_SYS_CHROOT"];
        NoNewPrivileges = true;
        PrivateMounts = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
        UMask = "0077";
        # The Android and Apple libraries in runtime/ match the 1.0.0 build
        # 1109 x86_64 profile; the worker and its metadata come from the store.
        BindReadOnlyPaths = [
          "/var/lib/wrapper-v2/runtime/system/lib64:/var/lib/wrapper-v2/rootfs/system/lib64"
          "/var/lib/wrapper-v2/runtime/system/bin/linker64:/var/lib/wrapper-v2/rootfs/system/bin/linker64"
          "${pkgs.local.wrapper-v2}/system/bin/apple-music-worker:/var/lib/wrapper-v2/rootfs/system/bin/apple-music-worker"
          "${pkgs.local.wrapper-v2}/system/usr/share/zoneinfo/tzdata:/var/lib/wrapper-v2/rootfs/system/usr/share/zoneinfo/tzdata"
          "${pkgs.local.wrapper-v2}/worker-profile.json:/var/lib/wrapper-v2/rootfs/worker-profile.json"
          "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt:/var/lib/wrapper-v2/rootfs/etc/ssl/certs/ca-certificates.crt"
        ];
        TemporaryFileSystem = ["/var/lib/wrapper-v2/rootfs/tmp:mode=1777,nosuid,nodev"];
      };
    };
  };
}
