# Local capture

Captured on 23 October 2026 from base revision `ee92b1cb5e84d4e543c7fce5803a69c5b5fa62d7` with the documented fixes and examples in this commit.

Nix 2.34.7 on Linux ARM64. The actual homeConfigurations.snowbear-aarch64 activationPackage.drvPath evaluated successfully with WITH_NVIM=0. The generated derivation was inspected and reported aarch64-linux, home-manager-generation and output out. This did not build a package closure or run its activation script. No profiles, services, VMs or network accounts changed; locked inputs were fetched into the Nix cache. WITH_NVIM=1, macOS and Multipass were not evaluated. The PNG is a rendered transcript of fields from the actual derivation.

Commands from the repository root after installing its documented dependencies:

```sh
WITH_NVIM=0 nix eval --impure --no-write-lock-file .#homeConfigurations.snowbear-aarch64.activationPackage.drvPath
make help
```
