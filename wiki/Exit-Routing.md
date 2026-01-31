# Exit routing

Exit routing forwards **internet traffic** from selected nodes through a
specific exit-capable node while preserving mesh traffic locally.

## Inventory fields

```ini
[mesh]
exit_nodes = charlie,sierra
exit_primary = charlie
exit_policy = latency
exit_check_interval_seconds = 20
enable_exit_for_nodes = all

[node "charlie"]
exit_out_iface = eth0
enable_nat = true
```

## Behavior

- Exit nodes enable forwarding + NAT on `exit_out_iface`.
- Exit-enabled nodes add policy routing and mark non-excluded traffic with
  `MARK_EXIT`, sending it to `TABLE_EXIT` via `wg0`.
- The **exit selector** (`wg-exit-selector`) enables exactly one exit at a time
  by adding `0.0.0.0/0` to the chosen peer.

## Notes

- Exit routing **requires** `mesh_cidr` so that the generator can exclude mesh
  traffic from policy marking.
- `Table = off` is set in generated configs to avoid wg-quick route conflicts.
