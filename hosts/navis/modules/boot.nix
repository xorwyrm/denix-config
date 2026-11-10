{
  config,
  delib,
  lib,
  ...
}:
delib.module {
  name = "navis";

  nixos.ifEnabled = {
    boot = {
      kernelParams = [
        "oops=panic"
        "panic=30"
      ];

      lanzaboote = {
        enable = true;
        pkiBundle = "/var/lib/sbctl";
        # Leave space on the 549 MiB ESP to stage the next kernel and initrd.
        configurationLimit = 2;
        autoEnrollKeys = {
          enable = true;
          includeMicrosoftKeys = true;
        };
        settings.timeout = 0;
      };

      initrd = {
        availableKernelModules = [
          "nvme"
          # The Ryzen's firmware TPM (fTPM) is a CRB device, not TIS.
          "tpm_crb"
          "xhci_pci"
        ];
        kernelModules = ["nvidia"];

        luks.devices."enc" = {
          device = "/dev/disk/by-uuid/9952fcd1-46eb-4c9c-ab7d-361d31fdb9a2";
          crypttabExtraOpts = ["tpm2-device=auto" "tpm2-measure-pcr=yes"];
        };

        systemd = {
          emergencyAccess = true;
          tpm2.enable = true;

          services.wipe-root = {
            description = "Rollback BTRFS root subvolume to a pristine state";
            wantedBy = ["initrd.target"];
            after = ["dev-mapper-enc.device"];
            requires = ["dev-mapper-enc.device"];
            before = ["sysroot.mount"];
            unitConfig.DefaultDependencies = "no";
            serviceConfig.Type = "oneshot";
            script = ''
              (
                set -xe

                btrfs_subvolume_delete_recursive() {
                  btrfs subvolume list -o "$1" |
                    cut -f 9- -d ' ' |
                    while read -r subvolume; do
                      btrfs_subvolume_delete_recursive "$mount_point/$subvolume"
                    done

                  btrfs subvolume delete "$1"
                }

                mount_point=/mnt
                mkdir -p "$mount_point"
                mount -t btrfs "/dev/mapper/enc" "$mount_point"

                trap 'umount "$mount_point" && rmdir "$mount_point"' EXIT

                btrfs_subvolume_delete_recursive \
                  "$mount_point/root"

                btrfs subvolume create "$mount_point/root"
              )
            '';
          };
        };
      };
    };

    hardware = {
      enableRedistributableFirmware = true;
      cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };

    systemd.settings.Manager.RebootWatchdogSec = "2min";
  };
}
