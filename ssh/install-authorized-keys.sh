#!/bin/sh
# Replace only our managed block, preserving other authorized keys.
set -eu
keys_file=${1:?usage: install-authorized-keys.sh PUBLIC_KEYS_FILE}
ssh_dir=${HOME:?}/.ssh
authorized_keys=$ssh_dir/authorized_keys
begin='# BEGIN nixos-config personal clients'
end='# END nixos-config personal clients'
mkdir -p "$ssh_dir"
chmod 0700 "$ssh_dir"
if [ -L "$authorized_keys" ]; then
  echo "Refusing to replace symlink: $authorized_keys" >&2
  exit 1
fi
tmp=$(mktemp "$ssh_dir/.authorized_keys.XXXXXX")
trap 'rm -f "$tmp"' EXIT HUP INT TERM
if [ -f "$authorized_keys" ]; then
  awk -v begin="$begin" -v end="$end" '
    $0 == begin { managed = 1; next }
    $0 == end { managed = 0; next }
    !managed { print }
  ' "$authorized_keys" >"$tmp"
fi
printf '%s\n' "$begin" >>"$tmp"
cat "$keys_file" >>"$tmp"
printf '%s\n' "$end" >>"$tmp"
chmod 0600 "$tmp"
mv "$tmp" "$authorized_keys"
