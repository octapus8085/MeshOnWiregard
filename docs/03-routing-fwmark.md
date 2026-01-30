# Routing and fwmark policy

## Standard constants

To avoid conflicts with Tailscale (`0x80000/0xff0000`), MeshOnWireguard uses:

- `MARK_EXIT=0x101`
- `MARK_MESH_BYPASS=0x102`
- `TABLE_EXIT=101`

These are validated in `wgmesh.sh validate` and intentionally far from Tailscale's mark/mask range.

## Policy routing behavior

Exit-enabled nodes use policy routing for the default route, while avoiding local and mesh traffic.

1. **Mark traffic** with `MARK_EXIT` in the `mangle` table.
2. **Exclude** destinations from marking:
   - Mesh CIDR
   - `127.0.0.0/8`
   - RFC1918 ranges (`10/8`, `172.16/12`, `192.168/16`)
   - Tailscale CGNAT range (`100.64.0.0/10`)
   - Optional output interface `tailscale0`
3. **Policy rule** sends marked traffic to `TABLE_EXIT`.
4. **Table route** sends default traffic via the WireGuard interface.

`Table = off` is set in the generated WireGuard config for exit-enabled nodes so `wg-quick` does not auto-manage routes.

## Idempotent PostUp/PostDown

All generated `PostUp`/`PostDown` commands are idempotent:

- `iptables -C ... || iptables -A ...`
- `ip rule add ... || true`
- `ip route replace ...`
- `ip route del ... || true`

This ensures repeatable automation and clean teardown.
