# Migration: Full Mesh → Star

This guide helps you migrate an existing full-mesh deployment to a star topology.

## 1) Choose hub nodes
Pick 1–3 nodes with stable connectivity and sufficient bandwidth. These will forward traffic between spokes.

## 2) Update inventory
In `[mesh]`:
- Set `topology = star`.
- Set `hubs = hub1,hub2`.

Make sure hubs have forwarding enabled:
```ini
[node "hub1"]
forwarding = true
```

## 3) Generate configs
```bash
./wgmesh.sh gen -c mesh.local.conf -o ./out
```

## 4) Apply to hubs first
Install configs on hubs, ensure they are up, then roll out spokes.

## 5) Verify forwarding
On a hub:
```bash
sysctl net.ipv4.ip_forward
iptables -L FORWARD -n -v
```

## 6) Failover considerations
- Single hub: `wg-failover` becomes optional.
- Multiple hubs: consider keeping `wg-failover` or plan for a hub selector in phase 2.

## Rollback
To return to full mesh, set `topology = fullmesh` and remove `hubs`, then regenerate and apply configs.
