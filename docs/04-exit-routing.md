# Exit routing

Exit routing allows a subset of nodes to forward internet traffic for the rest of the mesh.

## Enabling exit routing

```ini
[mesh]
exit_nodes = charlie,sierra
exit_primary = charlie
exit_policy = latency
exit_check_interval_seconds = 20
enable_exit_for_nodes = all
```

Per-node fields:

```ini
[node "charlie"]
exit_out_iface = eth0
enable_nat = true
```

## Behavior

- Exit nodes configure NAT and forwarding in `PostUp`/`PostDown`.
- Exit-enabled nodes use policy routing (`fwmark` + `TABLE_EXIT`) to route default traffic through WireGuard.
- `wg-exit-selector` keeps **one** exit node advertising `0.0.0.0/0` at a time.

## Disabling exit routing

Remove `exit_nodes` and `enable_exit_for_nodes` from `[mesh]` and regenerate configs. This removes the extra policy routing rules and selector service.

## NAT and forwarding rules

- Exit nodes add `iptables` rules for `FORWARD` and `MASQUERADE` on the configured `exit_out_iface`.
- Idempotent checks ensure rules are not duplicated.
