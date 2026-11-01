{ inputs }:

[
  (final: prev:
    let
      unstable = inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system};
    in {
      vimPlugins = unstable.vimPlugins;
      # Keep Bun >= 1.4.4 until unstable catches up; newer versions pass through.
      bun =
        if prev.lib.versionOlder unstable.bun.version "1.4.4" then
          unstable.bun.overrideAttrs (_: {
            version = "1.4.4";
            src = final.fetchurl ({
              aarch64-linux = {
                url = "https://github.com/oven-sh/bun/releases/download/bun-v1.4.4/bun-linux-aarch64.zip";
                hash = "sha256-uqa7NvUdblhWHgK76oJQOKnfRU9nPW13bou/hvjHhQ4=";
              };
              aarch64-darwin = {
                url = "https://github.com/oven-sh/bun/releases/download/bun-v1.4.4/bun-darwin-aarch64.zip";
                hash = "sha256-wkDX8My5DCY6hJ/NsJt+5iYw2SE0jtaq/ahrnVd7xRA=";
              };
              x86_64-linux = {
                url = "https://github.com/oven-sh/bun/releases/download/bun-v1.4.4/bun-linux-x64-baseline.zip";
                hash = "sha256-4ERutVmVdy65iUvrrppr42jZhai5Jx7hJEhvmUbu3XY=";
              };
            }.${prev.stdenv.hostPlatform.system});
          })
        else
          unstable.bun;
      d2 = unstable.d2;
      helm-ls = unstable.helm-ls;
      uv = unstable.uv;
    })

  (final: prev: {
    direnv =
      if prev.stdenv.isDarwin then
        prev.direnv.overrideAttrs (_old: {
          doCheck = false;
          doInstallCheck = false;
        })
      else
        prev.direnv;
  })
]
