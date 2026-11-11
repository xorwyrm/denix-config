{
  config,
  delib,
  pkgs,
  ...
}:
# The fleet key every machine and app signs in to the personal T3 Connect relay
# with; it never expires. The decrypted secret stays root-only, because fleet's
# agent sandbox runs as marshall and could read a marshall-owned one. A oneshot
# copies it into the T3 server's secret store (~/.t3/userdata/secrets), which
# the sandbox hides; the server and the desktop app read it from there.
delib.module {
  name = "system.t3ConnectFleetKey";

  options.system.t3ConnectFleetKey = with delib; {
    enable = boolOption false;
  };

  nixos.ifEnabled = let
    secrets = "/home/marshall/.t3/userdata/secrets";
  in {
    sops.secrets.t3_connect_fleet_key.sopsFile = ../../secrets/t3-connect.yaml;

    systemd.services.t3-connect-fleet-key = {
      description = "Install the T3 Connect fleet key for marshall's T3 Code";
      wantedBy = ["multi-user.target"];
      after = ["local-fs.target"];
      restartTriggers = [../../secrets/t3-connect.yaml];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${pkgs.coreutils}/bin/install -d -m 700 -o marshall -g users ${secrets}
        ${pkgs.coreutils}/bin/install -m 600 -o marshall -g users \
          ${config.sops.secrets.t3_connect_fleet_key.path} ${secrets}/connect-fleet-key.bin
      '';
    };
  };
}
