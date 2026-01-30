# Routing & Fwmarks

This project uses policy routing to keep mesh traffic local while optionally routing internet traffic through designated exit nodes. To avoid conflicts with Tailscale (which uses marks such as `0x80000` and `0xff0000`), MeshOnWiregard uses a distinct mark/table pair.

## Standard marks/tables
- `MARK_EXIT = 0x101`
- `TABLE_EXIT = 101`
- `MARK_MESH_BYPASS = 0x102` (reserved for future use)

## Policy routing overview
When exit routing is enabled on a node:
- `Table = off` is set in the WireGuard interface to prevent `wg-quick` auto routes.
- An `ip rule` sends traffic marked with `MARK_EXIT` to `TABLE_EXIT`.
- `TABLE_EXIT` contains a default route via `wg0` and a route to the mesh CIDR.

## Marking exclusions
Traffic **must not** be marked when it targets:
- Mesh CIDR (`mesh_cidr`)
- Loopback (`127.0.0.0/8`)
- RFC1918 ranges (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`)
- Tailscale CGNAT (`100.64.0.0/10`)
- Optional `tailscale_iface` (e.g., `tailscale0`)

These exclusions prevent conflicts with LANs, other overlay networks, and mesh traffic itself.

## Notes
- IPv6 is supported for addresses, but exit routing rules are IPv4-focused in v1.
- If you use Tailscale, set `tailscale_iface = tailscale0` in `[mesh]` to avoid marking its traffic.
