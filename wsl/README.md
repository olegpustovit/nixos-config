# gigacomp on WSL

Ubuntu 24.04 with the same `homeConfigurations.snowbear-x86_64` profile as
kyiv-grid. Reproduces the repo-managed tools and dotfiles; project data,
ROS packages, secrets and Tailscale node identities are separate.

Install on Windows:

```powershell
wsl --install Ubuntu-24.04 --name gigacomp --no-launch
wsl -d gigacomp -u root --exec git clone https://github.com/olegpustovit/nixos-config /home/snowbear/projects/nixos-config
wsl -d gigacomp -u root --exec bash /home/snowbear/projects/nixos-config/wsl/provision.sh
```

Make the checkout belong to `snowbear`, then apply Home Manager as that user:

```bash
cd ~/projects/nixos-config
export PATH=/nix/var/nix/profiles/default/bin:$PATH
nix build .#homeConfigurations.snowbear-x86_64.activationPackage --impure --out-link ~/.cache/home-manager-result
HOME_MANAGER_BACKUP_EXT=before-nix ~/.cache/home-manager-result/activate
sudo usermod --shell /home/snowbear/.nix-profile/bin/fish snowbear
sudo tailscale up --hostname=gigacomp --accept-dns=false
```

Keep the authentication command running while signing in. Restart only gigacomp
to apply the hostname and default user. Run `wsl/keep-alive.ps1` on Windows to
start WSL at login and keep remote access available while Windows is awake.

```bash
ssh snowbear@gigacomp
mosh snowbear@gigacomp
```

WSL distributions share a network namespace. The provisioner isolates gigacomp's
Tailscale, SSH and Mosh with a private veth link to avoid conflicts with kyiv-grid.
SSH requires public keys; Tailscale DNS is disabled locally to preserve the WSL
resolver. Other clients can resolve gigacomp through MagicDNS.

Personal SSH public keys live in `ssh/authorized_keys`. Home Manager updates a
marked block on Linux and macOS, preserving entries outside it. Reapply Home
Manager on each host after editing the list. A removed managed key can still
exist outside that block; remove those duplicates explicitly to revoke access.
Private keys stay on their devices. The WSL provisioner also applies this list.
