# Topologies

MeshOnWiregard supports two topologies:

- **Full mesh** (default): every node peers with every other node.
- **Star (hub/spoke)**: spokes peer only with hub nodes; hubs peer with all
  spokes and each other.

## Full mesh

**Pros**
- Simple mental model.
- No single hub dependency.

**Cons**
- N^2 peering complexity as node count grows.
- More overhead in configuration and endpoint maintenance.
- Harder to centralize NAT/exit routing.

## Star (recommended)

**Pros**
- Reduces peers on spokes (only hub(s)).
- Centralizes routing/NAT/egress.
- Aligns with common "core + edge" designs.

**Cons**
- Hubs become critical infrastructure.
- Requires hub forwarding and firewall policy.

### Star rules in v1

- Spokes peer **only** with hubs.
- Hubs peer with **all** spokes and other hubs.
- `AllowedIPs` remain `/32` per node.
- Hub nodes enable IPv4 forwarding and wg-to-wg forwarding rules in PostUp.

### Hub count and failover

- **Single hub**: `wg-failover` is usually unnecessary. If the hub is down,
  connectivity is down.
- **Multiple hubs**: spokes can peer with multiple hubs. v1 does **not** include
  automated hub selection, but the inventory supports a future `hub_selection`
  mode.

## How to choose

- **<= 5 nodes** with equal importance: full mesh may be acceptable.
- **> 5 nodes** or need centralized egress: use star.

For a migration plan, see
[docs/06-migration-guide.md](06-migration-guide.md).
