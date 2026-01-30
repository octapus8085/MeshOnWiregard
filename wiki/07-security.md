# Security

## Keys and permissions

- Store private keys with `0600` permissions.
- Prefer `private_key_path` to avoid embedding secrets in configs.
- Restrict access to `/etc/wireguard`.

## Firewall posture

- Limit inbound UDP to the WireGuard port.
- Allow only required forwarding (wg->wg for hubs, wg->WAN for exits).
- Audit iptables/nft rules periodically.

## sysctl hardening

- `net.ipv4.ip_forward=1` is required for hubs and exit nodes.
- Apply sysctl settings only on hosts that need forwarding.

## Operational hygiene

- Rotate keys if endpoints or hosts are compromised.
- Use `wg show` to confirm peer state and handshakes.
