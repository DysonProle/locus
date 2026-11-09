# The interface (ui/): the built page plus the host that serves it beside the
# ship (server/host.mjs), and the store seed and upgrade scripts. The host and
# scripts use only Node's built-ins at run time, so node_modules is not kept.
{
  lib,
  buildNpmPackage,
  nodejs,
  makeWrapper,
}:

buildNpmPackage {
  pname = "locus-ui";
  version = "0.0.1";

  src = lib.fileset.toSource {
    root = ../../ui;
    fileset = lib.fileset.unions [
      ../../ui/index.html
      ../../ui/package.json
      ../../ui/package-lock.json
      ../../ui/vite.config.js
      ../../ui/credits.json
      ../../ui/src
      ../../ui/server
      ../../ui/scripts
    ];
  };

  npmDepsHash = "sha256-KitF5T7DAdLzZZ+ZHEGMfOWAj3N85lYh1i8rFZlFDQ4=";

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    dir=$out/lib/locus-ui
    mkdir -p "$dir" $out/bin
    cp -r dist server src scripts package.json "$dir"/
    makeWrapper ${lib.getExe nodejs} $out/bin/locus-ui-host --add-flags "$dir/server/host.mjs"
    makeWrapper ${lib.getExe nodejs} $out/bin/locus-ui-seed --add-flags "$dir/scripts/seed.mjs"
    makeWrapper ${lib.getExe nodejs} $out/bin/locus-ui-upgrade --add-flags "$dir/scripts/upgrade-store.mjs"
    runHook postInstall
  '';

  meta = {
    description = "Locus interface and its host (serves the page, holds the ship login, runs the agent)";
    mainProgram = "locus-ui-host";
  };
}
