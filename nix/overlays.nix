{ inputs }:

[
  (final: prev:
    let
      unstable = inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system};
    in {
      vimPlugins = unstable.vimPlugins;
      # ponytail: drop this override when nixpkgs-unstable ships Bun >= 1.4.2.
      bun =
        if prev.stdenv.hostPlatform.system == "aarch64-linux" then
          unstable.bun.overrideAttrs (_: {
            version = "1.4.2";
            src = final.fetchurl {
              url = "https://github.com/oven-sh/bun/releases/download/bun-v1.4.2/bun-linux-aarch64.zip";
              hash = "sha256-VDKLvC2cjgyfiSxUTWbFeoO4QTnjSQnl7oF1jxrI/ac=";
            };
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
