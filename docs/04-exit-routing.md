# Exit Routing

Exit routing allows selected nodes to forward internet traffic through one or more **exit nodes** while keeping mesh peer connectivity intact.

## Requirements
- `mesh_cidr` defined in `[mesh]`.
- `mesh_cidr` must be IPv4 for exit routing in v1.
- `exit_nodes` and `enable_exit_for_nodes` configured in `[mesh]`.
- Exit nodes must define `exit_out_iface` and `enable_nat = true`.
- `exit_check_interval_seconds` must be set.

## Behavior
- Exit-enabled nodes:
  - add policy routing rules (`MARK_EXIT`, `TABLE_EXIT`),
  - keep mesh CIDR traffic local,
  - set `Table = off` to avoid wg-quick auto routes.
- Exit nodes:
  - enable IPv4 forwarding,
  - add `MASQUERADE` NAT rules for outbound traffic.

## Inventory example
```ini
[mesh]
mesh_cidr = 10.40.0.0/24
exit_nodes = charlie,sierra
exit_primary = charlie
exit_policy = latency
exit_check_interval_seconds = 20
enable_exit_for_nodes = all

[node "charlie"]
exit_out_iface = eth0
enable_nat = true

[node "sierra"]
exit_out_iface = ens3
enable_nat = true
```

## Exit selector
The `wg-exit-selector` service chooses a single active exit and updates AllowedIPs so only one peer carries `0.0.0.0/0` at a time. This keeps your mesh routes intact while avoiding split-brain internet exits.

## NAT + forwarding rules
Exit nodes insert idempotent `iptables` rules:
- `FORWARD` accepts traffic from `wg0` to `exit_out_iface`.
- `POSTROUTING` uses `MASQUERADE` on `exit_out_iface`.

## Disabling exit routing
- Remove `exit_nodes` and `enable_exit_for_nodes` from `[mesh]`.
- Run `wgmesh.sh gen` and apply the updated config.
