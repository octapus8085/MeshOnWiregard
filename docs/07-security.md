# Security

## Key management

- Prefer `private_key_path` with strict permissions (`chmod 600`).
- Use `--gen-keys` locally and store keys in secure secrets management.
- Rotate keys regularly and update inventory accordingly.

## Permissions

- `wgmesh.sh apply` installs configs under `/etc/wireguard`.
- Run installs with `sudo` and ensure the output directory is protected.

## Firewalling

- Limit inbound UDP to the WireGuard port (`51820` by default).
- Allow forwarding rules only where needed (hubs and exit nodes).
- For internet exits, verify NAT rules only target the intended egress interface.

## Kernel forwarding

- Hubs and exit nodes require `net.ipv4.ip_forward=1`.
- Nodes without forwarding should keep `ip_forward=0`.

## Tailscale coexistence

- MeshOnWireguard avoids Tailscale's mark range (`0x80000/0xff0000`).
- Marked traffic excludes `100.64.0.0/10` and `tailscale0` output.
