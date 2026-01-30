# Routing and fwmark policy

## Policy routing model

When exit routing is enabled, nodes use policy routing to send **internet
traffic** through the mesh while keeping **mesh/LAN** traffic local.

The generator:

- disables wg-quick auto routes (`Table = off`),
- adds a policy rule to route marked packets via a custom table,
- adds a default route via `wg0` in that table,
- excludes mesh/LAN/Tailscale ranges from being marked.

## Standard marks and tables

The project standardizes marks/tables to avoid conflicts with Tailscale:

- `MARK_EXIT = 0x101`
- `TABLE_EXIT = 101`
- `MARK_MESH_BYPASS = 0x102`
- Tailscale uses `0x80000` and mask `0xff0000`.

These values are validated to avoid overlaps with the Tailscale mark space.

## Exclusions (not marked for exit routing)

The policy rules exclude traffic destined for:

- `mesh_cidr` (e.g., `10.40.0.0/24`)
- RFC1918 ranges: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`
- Loopback: `127.0.0.0/8`
- Tailscale CGNAT: `100.64.0.0/10`
- Optional: `tailscale0` output interface (if present)

## Table behavior

With `Table = off`, WireGuard does **not** auto-install routes for `AllowedIPs`.
Instead, the generator explicitly manages routes and policy rules.
