{
  delib,
  inputs,
  lib,
  ...
}:
delib.module {
  name = "navis";

  home.ifEnabled.wayland.windowManager.hyprland.settings.monitor = lib.mkForce [
    {
      output = "desc:LG Electronics LG ULTRAGEAR 411BOYQ05442";
      mode = "2560x1440@180";
      position = "0x0";
      scale = 1;
    }
    # The NanoKVM's HDMI capture shows up as a second output; keep it off so
    # Hyprland only drives the LG.
    {
      output = "desc:VCS Connector 0x00451531";
      disabled = true;
    }
  ];

  nixos.ifEnabled = {
    services.greetd = {
      enable = true;
      settings = rec {
        initial_session = {
          command = "${inputs.hyprland.packages.x86_64-linux.hyprland}/bin/start-hyprland";
          user = "marshall";
        };
        default_session = initial_session;
      };
    };
  };
}
