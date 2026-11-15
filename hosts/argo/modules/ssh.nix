{delib, ...}:
delib.module {
  name = "argo";

  nixos.ifEnabled = {myconfig, ...}: {
    users.users.${myconfig.constants.username}.openssh.authorizedKeys.keys = myconfig.sshKeys.personal;
  };
}
