# MeshOnWireguard Overview

MeshOnWireguard is an inventory-driven generator for WireGuard configurations with optional automation helpers (failover and exit selection). This refactor standardizes IP planning, policy routing marks, and topologies so the generated configuration matches operational needs.

## Goals for v1

- **Inventory-first generation**: single source of truth for node addresses, endpoints, and per-node options.
- **RFC1918/ULA addressing**: keep mesh addresses private and predictable.
- **Star topology first**: optimize for hub/spoke deployments and limit peer count on spokes.
- **Policy routing safety**: avoid fwmark conflicts with Tailscale and common defaults.
- **Idempotent networking commands**: `PostUp`/`PostDown` can run repeatedly without drift.

## Documentation Map

- [Inventory schema](01-inventory-spec.md)
- [Topologies](02-topologies.md)
- [Routing & fwmark policy](03-routing-fwmark.md)
- [Exit routing](04-exit-routing.md)
- [Troubleshooting](05-troubleshooting.md)
- [Migration guide](06-migration-guide.md)
- [Security guidance](07-security.md)
- [Dynamic routing roadmap](08-roadmap-dynamic-routing.md)
- [Tasks & acceptance criteria](09-tasks.md)

## Recommended defaults

- `mesh_cidr`: RFC1918 (e.g. `10.40.0.0/24`) or ULA (`fd00:40::/64`).
- `topology`: `star` with one or more hubs.
- `hub_selection`: `static` for v1; latency-based selection is a phase 2 task.

## Operational notes

- **Star topology** reduces peer count on spokes and keeps routing logic centralized at hubs.
- **Single-hub star** typically does not need `wg-failover` for mesh traffic, but it remains useful for endpoint-level failover or multi-hub use cases.
- **Exit routing** uses dedicated `fwmark`/table constants and avoids marking LAN, mesh, or Tailscale ranges.
