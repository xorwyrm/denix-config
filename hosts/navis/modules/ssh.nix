{delib, ...}:
delib.module {
  name = "navis";

  nixos.ifEnabled = {myconfig, ...}: {
    users.users.${myconfig.constants.username}.openssh.authorizedKeys.keys = myconfig.sshKeys.personal;

    systemd.tmpfiles.rules = ["d /scratch/tmp 1777 root root 10d"];
  };
}
