{
  config,
  delib,
  ...
}:
# The PDS for Mars's xorwyrm.sh identity, kept separate from skulldogged.dev's
# account on Polaris (sky.skulldogged.dev). Its data is in /var/lib/pds on the
# mirror, staged for the nightly backup (backup.nix). It's reached through the
# argo-knot tunnel (knot.nix), because Stalwart holds public 443, and sends
# mail as noreply@xorwyrm.sh, a send-only account in Stalwart.
delib.module {
  name = "argo";

  nixos.ifEnabled = {
    # JWT secret, admin password, PLC rotation key and the SMTP URL with
    # noreply@xorwyrm.sh's password.
    sops.secrets.pds_env.sopsFile = ../../../../secrets/argo-xorwyrm.yaml;

    services.bluesky-pds = {
      enable = true;
      pdsadmin.enable = true;
      environmentFiles = [config.sops.secrets.pds_env.path];

      settings = {
        PDS_HOSTNAME = "pds.xorwyrm.sh";
        PDS_PORT = 2583;
        PDS_EMAIL_FROM_ADDRESS = "noreply@xorwyrm.sh";
        PDS_CONTACT_EMAIL_ADDRESS = "hi@xorwyrm.sh";
        # Cloudflare's proxy refuses request bodies over 100 MB.
        PDS_BLOB_UPLOAD_LIMIT = "95000000";
      };
    };
  };
}
