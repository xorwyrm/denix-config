{delib, ...}:
delib.module {
  name = "polaris";

  nixos.ifEnabled = {myconfig, ...}: {
    users.users.${myconfig.constants.username}.openssh.authorizedKeys.keys =
      myconfig.sshKeys.personal
      ++ ["restrict ${myconfig.sshKeys.t3Deploy}"];
  };
}
