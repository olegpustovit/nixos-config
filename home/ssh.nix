# Apply personal client public keys on every Home Manager host.
{ lib, pkgs, ... }:
{
  home.activation.authorizePersonalClients = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.runtimeShell} ${../ssh/install-authorized-keys.sh} ${../ssh/authorized_keys}
  '';
}
