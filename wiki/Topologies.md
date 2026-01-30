# Topologies

## Full mesh

**Full mesh** means every node peers with every other node. This was the
original default and remains supported for backward compatibility.

Pros:
- Direct connectivity between all nodes.
- No hub dependency.

Cons:
- O(N²) peer count at scale.
- More complex operational state and routing.

## Star (recommended)

**Star** (hub/spoke) means:

- **Spokes** peer only with hubs.
- **Hubs** peer with all spokes (and other hubs).
- Hubs forward traffic between spokes.

Pros:
- Reduced peer count for spokes.
- Simpler growth and management.

Cons:
- Hub dependency for spoke-to-spoke paths.

### Configuration

```ini
[mesh]
topology = star
hubs = alpha,bravo
hub_selection = static
```

### Hub forwarding

Hubs should allow forwarding:

- `net.ipv4.ip_forward=1`
- Allow `wg0 -> wg0` forwarding in firewall rules.

The generator adds forwarding rules for hub nodes.

## Failover guidance

- **Single hub**: `wg-failover` is optional; no failover logic is required
  for intra-mesh connectivity because all spokes depend on one hub.
- **Multiple hubs**: future work can add a hub selection mechanism
  (latency-based or manual selector). This is documented in the roadmap.
