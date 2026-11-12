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
    rev = "d8d183281f5cb7704973c27a98646b65326e89ce";
    hash = "sha256-UrlMsjyVY7k6FIo2x9uxWdsicPwUVHT1Rhl9xKYeTkM=";
  };

  # The crate is in ssh/; it builds in the site's text from src/data/site.json.
  cargoRoot = "ssh";
  buildAndTestSubdir = "ssh";
  cargoHash = "sha256-nDB0nc4Aoo8WeWt0hAeyvnRSPVk1fucE+XKtRaamMo0=";

  meta = {
    description = "xorwyrm.sh in a terminal, over ssh";
    homepage = "https://github.com/xorwyrm/xorwyrm.sh";
    mainProgram = "xorwyrm-ssh";
    platforms = lib.platforms.linux;
  };
}
