{delib, ...}:
# The fleet's SSH keys, by what they're for. Hosts authorize these instead of
# hand-edited authorized_keys files.
delib.module {
  name = "sshKeys";

  options.sshKeys = with delib; {
    # Mars's own devices: ordinary, unrestricted logins. The Windows laptop
    # (mars@navis-win) has no agent key: agents elsewhere don't reach it.
    personal = readOnly (listOfOption str [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB7fPGt6KAzwOVQqOV0JT74unUXDbdQHvD3yufYyvLKW mars@navis-win"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBsHqYKt58eFcZo7UdPX45CaEhLeGge+cE1Gdt74IHSv MacBook"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL2vmQG3o3yMTXUbHYM7evCpUo/V+gK8Lofajt/hEjrB navis"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIARRfEXoLrza1riqJJb0qFVYqOhNpXJEP9VI11K2RPJH marshall@navis"
      # Sealed to navis's TPM (re-created 2026-11-09 after the move to the desktop).
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBKRBwdnopyERxlOH650eeDYbuH2Kp8vxHgaCMzYNEchpnGHDdEXFCJUNuYqznh9PbBsDEk7jc9ppJb/fd41vWSA= navis-tpm-polaris"
    ]);

    # Each host's own key (~/.ssh/id_ed25519_fleet), which its agents and
    # services use to reach the other hosts (system.fleetSsh).
    agents = readOnly (attrsOfOption str {
      argo = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINmHB1IqZ2XbtRnxyXL7uAnuFB1e8dhGhBlHTTFL0IKU fleet-builder";
      polaris = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGEtGBP9oDI1KcX1ZPh/QL/7TJzykmRN4zB3KljtG8BP fleet-polaris";
      canis = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICCjjPRNWczwWtChAMOGLYHKTRvmhw1pNvy29b36hifi fleet-canis";
      # The desktop's macOS install (reinstalled November 2026; user bit).
      vela = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDbGJc5nBO/luH62TKk8L1KJQ/G1XIWcYVBohiRg6gru fleet-vela";
      # The desktop's NixOS install.
      navis = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILXHezNopXrrVepuwOW9DUV5brv1bDmXftCwCgQl8DZ/ fleet-navis";
    });

    # argo's T3 release channel, deploying releases to Polaris and canis.
    t3Deploy = readOnly (strOption "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKDUtTH6Q1dhBf6GgMZDPnFBzpeNcx+emd7BRRFYPGGF t3-channel-deploy@argo");
  };
}
