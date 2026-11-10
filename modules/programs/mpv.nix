{
  delib,
  pkgs,
  lib,
  ...
}:
delib.module {
  name = "programs.mpv";

  options.programs.mpv = with delib; {
    enable = boolOption false;

    hardwareDecodeDevice =
      description
      (strOption "")
      "VA-API device used for copy-back hardware video decoding. Empty disables hardware decoding.";

    nvdec =
      description
      (boolOption false)
      "Use NVDEC copy-back hardware decoding on an NVIDIA GPU instead of VA-API.";
  };

  home.ifEnabled = {myconfig, ...}: let
    cfg = myconfig.programs.mpv;
    hardwareDecodeEnabled = !cfg.nvdec && cfg.hardwareDecodeDevice != "";
  in {
    programs.mpv = {
      enable = true;
      extraMakeWrapperArgs = lib.optionals hardwareDecodeEnabled [
        "--set"
        "LIBVA_DRIVER_NAME"
        "iHD"
      ];
      scripts = [pkgs.mpvScripts.uosc];
      config =
        lib.optionalAttrs hardwareDecodeEnabled {
          hwdec = "vaapi-copy";
          vaapi-device = cfg.hardwareDecodeDevice;
        }
        // lib.optionalAttrs cfg.nvdec {
          hwdec = "nvdec-copy";
        };
    };
  };
}
