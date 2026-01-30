# Topologies

## Full mesh (legacy)

- Every node peers with every other node.
- Best for small meshes where peer count is manageable.
- Default to preserve backward compatibility.

## Star (recommended)

- **Spokes** peer only with hub nodes.
- **Hubs** peer with every node (including other hubs if present).
- Hubs forward traffic between spokes.

### Benefits

- Lower peer count on spokes.
- Simplified routing policy.
- Centralized failure domains and monitoring.

### Tradeoffs

- Hubs become critical infrastructure for mesh reachability.
- In single-hub deployments, the hub is a single point of failure.

### Configuration

```ini
[mesh]
interface = wg0
mesh_cidr = 10.40.0.0/24
topology = star
hubs = alpha,charlie
hub_selection = static
```

### Hub forwarding requirements

Hubs must forward between peers:

- `net.ipv4.ip_forward=1`
- Allow `wg0 -> wg0` forwarding (iptables `FORWARD` rules)

`wgmesh.sh` adds these rules automatically for hub nodes in star mode.

## Hub selection behavior

- **static**: all spokes peer with the same hub list. v1 behavior.
- **latency**: future phase, selection by RTT/health. Documented in the roadmap.

## Failover considerations

- **Single hub**: `wg-failover` is typically optional for mesh connectivity (no alternate hub exists).
- **Multiple hubs**: allow manual or future latency-based selection of a preferred hub.
- **Endpoint failover** still helps when a hub hostname resolves to a failed upstream IP.
