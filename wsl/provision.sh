#!/usr/bin/env bash
# Run as root inside a fresh Ubuntu 24.04 WSL instance.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
# Prevent package post-install hooks from starting listeners before isolation.
if [ -e /usr/sbin/policy-rc.d ]; then
  echo 'Existing policy-rc.d: inspect before provisioning' >&2
  exit 1
fi
printf '#!/bin/sh\nexit 101\n' >/usr/sbin/policy-rc.d
chmod 0755 /usr/sbin/policy-rc.d
trap 'rm -f /usr/sbin/policy-rc.d' EXIT
apt-get update
apt-get install -y ca-certificates curl git fish mosh openssh-server sudo xz-utils locales docker.io docker-compose-v2
if ! id snowbear >/dev/null 2>&1; then
  useradd --create-home --uid 1000 --shell /usr/bin/fish snowbear
fi
chown snowbear:snowbear /home/snowbear
usermod -aG sudo,docker snowbear
printf 'snowbear ALL=(ALL:ALL) NOPASSWD: ALL\n' >/etc/sudoers.d/snowbear
chmod 0440 /etc/sudoers.d/snowbear
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8
cat >/etc/wsl.conf <<'EOF'
[boot]
systemd=true
[user]
default=snowbear
[network]
hostname=gigacomp
EOF
printf 'gigacomp\n' >/etc/hostname
# Hostname takes effect when WSL restarts.
# SSH listens inside the isolated network namespace, avoiding port conflicts.
cat >/usr/local/sbin/gigacomp-ssh-bind <<'EOF'
#!/bin/sh
set -eu
ip=0.0.0.0
printf 'ListenAddress %s\nPasswordAuthentication no\nKbdInteractiveAuthentication no\nPermitRootLogin no\n' "$ip" >/etc/ssh/sshd_config.d/00-gigacomp.conf
EOF
chmod 0755 /usr/local/sbin/gigacomp-ssh-bind
mkdir -p /etc/systemd/system/ssh.service.d
cat >/etc/systemd/system/ssh.service.d/tailscale.conf <<'EOF'
[Unit]
Wants=tailscaled.service
After=tailscaled.service
[Service]
ExecStartPre=/usr/local/sbin/gigacomp-ssh-bind
Restart=on-failure
RestartSec=10
EOF
systemctl disable --now ssh.socket || true
if ! command -v tailscale >/dev/null; then
  curl -fsSL https://tailscale.com/install.sh -o /tmp/gigacomp-tailscale-install.sh
  sh /tmp/gigacomp-tailscale-install.sh
fi
# A separate UDP port also avoids the other WSL node's WireGuard listener.
sed -i 's/^PORT=.*/PORT="41642"/' /etc/default/tailscaled
# Tailscale and its SSH/Mosh children get a separate network namespace.
cat >/usr/local/sbin/gigacomp-network <<'EOF'
#!/bin/bash
set -euo pipefail
if ! ip netns list | grep -q '^gigacomp\b'; then
  ip netns add gigacomp
fi
if ! ip link show giga-host >/dev/null 2>&1; then
  ip link add giga-host type veth peer name giga-guest
  ip link set giga-guest netns gigacomp
fi
ip addr replace 10.203.0.1/30 dev giga-host
ip link set giga-host up
ip -n gigacomp addr replace 10.203.0.2/30 dev giga-guest
ip -n gigacomp link set giga-guest up
ip -n gigacomp link set lo up
ip -n gigacomp route replace default via 10.203.0.1
sysctl -w net.ipv4.ip_forward=1
iptables -t nat -C POSTROUTING -s 10.203.0.0/30 -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -s 10.203.0.0/30 -j MASQUERADE
iptables -C FORWARD -i giga-host -j ACCEPT 2>/dev/null || iptables -I FORWARD -i giga-host -j ACCEPT
iptables -C FORWARD -o giga-host -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || iptables -I FORWARD -o giga-host -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
EOF
chmod 0755 /usr/local/sbin/gigacomp-network
cat >/etc/systemd/system/gigacomp-network.service <<'EOF'
[Unit]
Description=Isolated network for gigacomp Tailscale, SSH and Mosh
After=network-online.target
Wants=network-online.target
Before=tailscaled.service ssh.service
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/gigacomp-network
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
for service in tailscaled ssh; do
  mkdir -p /etc/systemd/system/$service.service.d
  cat >/etc/systemd/system/$service.service.d/network.conf <<'EOF'
[Unit]
Requires=gigacomp-network.service
After=gigacomp-network.service
[Service]
NetworkNamespacePath=/run/netns/gigacomp
EOF
done
systemctl daemon-reload
systemctl enable --now gigacomp-network
systemctl enable --now tailscaled docker
if [ ! -x /nix/var/nix/profiles/default/bin/nix ]; then
  curl -fsSL https://nixos.org/nix/install -o /tmp/gigacomp-nix-install.sh
  sh /tmp/gigacomp-nix-install.sh --daemon --yes
fi
mkdir -p /etc/nix
if ! grep -q '^experimental-features' /etc/nix/nix.conf; then
  printf '\nexperimental-features = nix-command flakes\n' >>/etc/nix/nix.conf
fi
systemctl enable --now nix-daemon
systemctl restart nix-daemon
ssh-keygen -A
systemctl enable --now ssh.service
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sudo -H -u snowbear sh "$repo_dir/ssh/install-authorized-keys.sh" "$repo_dir/ssh/authorized_keys"
printf 'gigacomp base provisioned; authenticate Tailscale to enable remote access.\n'
