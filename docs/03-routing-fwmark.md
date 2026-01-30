# Routing & fwmark plan

Exit routing uses policy routing so that only **internet-bound** traffic is sent
through a selected exit node. The generator standardizes the marks and routing
table to avoid conflicts.

## Constants

- `MARK_EXIT = 0x101`
- `TABLE_EXIT = 101`
- `MARK_MESH_BYPASS = 0x102` (reserved for future use)

These marks intentionally avoid Tailscale's mark range
(`0x80000` with mask `0xff0000`). The generator validates conflicts.

## Policy routing workflow (exit-enabled nodes)

1. `Table = off` is set in the generated `[Interface]` to stop `wg-quick` from
   auto-adding routes.
2. An `ip rule` sends marked traffic to `TABLE_EXIT`.
3. `TABLE_EXIT` contains a default route via the WireGuard interface.
4. A mangle rule marks **non-bypassed** traffic with `MARK_EXIT`.
5. Bypass rules `RETURN` (do not mark) for:
   - `mesh_cidr` (the mesh subnet)
   - `127.0.0.0/8`
   - RFC1918 LAN ranges (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`)
   - `100.64.0.0/10` (CGNAT/Tailscale)
   - Output interface `tailscale0` (optional)

## Idempotency

All `PostUp`/`PostDown` commands are generated to be idempotent:

- `iptables -C ... || iptables -A ...`
- `iptables -D ... || true`
- `ip rule add ... || true`
- `ip route replace ...`

This allows safe re-apply and rollback without duplicate rules.
