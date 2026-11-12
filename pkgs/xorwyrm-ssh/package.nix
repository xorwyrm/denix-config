# xorwyrm.sh over ssh: the ssh server that shows the site in a terminal, built
# from the site's own repo (its ssh/ folder). To update, point rev at a newer
# commit and refresh the hashes.
{
  fetchFromGitHub,
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "xorwyrm-ssh";
  version = "0-unstable-2026-11-12";

  src = fetchFromGitHub {
    owner = "xorwyrm";
    repo = "xorwyrm.sh";
    rev = "a9b7d7bd204492b250f0048924fa6a6e3658c48c";
    hash = "sha256-hpv53aiNB79HU0muZtPpbk8AIiC2E99W0+tvsx+w4bY=";
  };

  # The crate is in ssh/; it builds in the site's text from src/data/site.json.
  cargoRoot = "ssh";
  buildAndTestSubdir = "ssh";
  cargoHash = "sha256-rZ1vSv7r0gWTHpmjvDB7ui/3AEQ5+WsUo7n2On98ioE=";

  meta = {
    description = "xorwyrm.sh in a terminal, over ssh";
    homepage = "https://github.com/xorwyrm/xorwyrm.sh";
    mainProgram = "xorwyrm-ssh";
    platforms = lib.platforms.linux;
  };
}
