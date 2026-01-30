# Security

## Key material
- Store private keys with file permissions `0600`.
- Prefer `private_key_path` over inlining the private key.
- Do not commit real keys into version control.

## Access control
- Limit SSH access for `apply-remote` via SSH config or firewall rules.
- Lock down `wgmesh.sh` execution to privileged admins.

## Firewall
- Allow UDP `port` on hubs and spokes as needed.
- When using exit routing, ensure NAT and forwarding rules are present and restricted to required interfaces.

## IP forwarding
- Hubs and exit nodes require `net.ipv4.ip_forward=1`.
- MeshOnWiregard sets this automatically in PostUp and resets on PostDown.

## Systemd
- `wg-quick@wg0.service` should be enabled on nodes.
- `wg-failover.timer` and `wg-exit-selector.timer` should run only if the feature is needed.
