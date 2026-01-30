# Security

## Key handling

- Prefer `private_key_path` with strict permissions (0600/0700) over inline
  `private_key` values.
- If you must include keys in the inventory, store the file securely and limit
  access.

## Permissions

- Generated configs and key files should be readable only by root.
- The apply commands install configs under `/etc/wireguard` and require sudo.

## Firewall posture

- Allow UDP on the WireGuard port for inbound peer traffic.
- Use `iptables` or `nftables` to control forwarding policy.
- Exit nodes should allow forward + NAT only for intended interfaces.

## IP forwarding

- Hubs and exit nodes set `net.ipv4.ip_forward=1` via PostUp.
- Validate system defaults and ensure they match your security posture.

## SSH access

- For `apply-remote`, ensure SSH keys are scoped appropriately and do not reuse
  privileged keys across environments.
