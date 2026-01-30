# Topologies: Full Mesh vs Star

## Full mesh (legacy/default)
**Definition:** Every node peers with every other node.

**Pros**
- No hub dependency for connectivity.
- Simple mental model.

**Cons**
- N² peer growth and configuration complexity.
- Harder to scale as the fleet grows.

## Star (recommended)
**Definition:** Spokes peer only with hubs. Hubs peer with all nodes. Hubs forward traffic between spokes.

**Pros**
- Scales better: spokes don’t need all peers.
- Simplifies operational routing decisions.
- Easier to extend to dynamic routing later.

**Cons**
- Hubs become critical infrastructure.
- Hub sizing, availability, and routing rules matter.

## Configuration rules
- Set `topology = star` in `[mesh]`.
- Provide `hubs = node1,node2,...`.
- Spokes only peer with hubs.
- Hubs peer with all nodes, including other hubs.
- Hubs must allow forwarding (`ip_forward=1` + wg→wg forwarding rules).

## Recommended default
For most deployments, **star** is the default choice due to scale and operational simplicity. Use full mesh only for small clusters or when you explicitly need peer-to-peer directness without a hub.

## Failover trade-offs
- **Single hub:** `wg-failover` becomes optional; no hub switching is needed if you operate a single stable hub.
- **Multiple hubs:** keep `wg-failover` or a future hub selector to switch spokes to the best hub.
