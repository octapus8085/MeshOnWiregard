# Migration Guide (Full Mesh → Star)

## Before you begin

- Identify the nodes that will serve as hubs.
- Confirm hub capacity (CPU, bandwidth, uptime).
- Ensure IP plan is RFC1918/ULA and standardized.

## Step-by-step migration

1. **Add `mesh_cidr`** to `[mesh]`.
2. **Set `topology = star`** and list hubs in `hubs`.
3. **Enable hub forwarding** (automated by `wgmesh.sh` when hubs are listed).
4. **Regenerate configs** and roll out hubs first.
5. **Roll out spokes** once hubs are active.

## Example patch

```ini
[mesh]
interface = wg0
mesh_cidr = 10.40.0.0/24
topology = star
hubs = alpha
hub_selection = static
```

## Operational notes

- During migration, you can temporarily keep full mesh by not setting `topology`.
- Spokes will only peer with hubs once star mode is enabled, so deploy hubs first.
- If only one hub exists, `wg-failover` is optional for mesh connectivity. It remains useful for endpoint-level failover.
