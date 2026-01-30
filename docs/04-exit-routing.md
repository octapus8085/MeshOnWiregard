# Exit routing

Exit routing allows selected nodes to send internet-bound traffic through one or
more exit-capable peers. v1 uses a lightweight selector that adjusts `AllowedIPs`
so only one exit advertises `0.0.0.0/0` at a time.

## Required mesh fields

```ini
[mesh]
exit_nodes = hub1,hub2
exit_primary = hub1
exit_policy = latency   # or manual
exit_check_interval_seconds = 20
enable_exit_for_nodes = all
```

## Required exit-node fields

```ini
[node "hub1"]
exit_out_iface = eth0
enable_nat = true
```

## What gets configured

- Exit nodes enable `net.ipv4.ip_forward=1` and add forwarding + MASQUERADE
  rules on `exit_out_iface`.
- Exit-enabled nodes install policy routing (see
  [docs/03-routing-fwmark.md](03-routing-fwmark.md)).
- The `wg-exit-selector` timer measures reachability and applies the selected
  exit's `0.0.0.0/0` to keep only one active at a time.

## Notes and tradeoffs

- Exit routing is independent of topology. Star is recommended so egress
  naturally passes through hub(s).
- With a **single hub**, the selector is optional but still useful if you want
  to toggle egress dynamically.
- With **multiple hubs**, v1 uses the exit selector for egress; hub selection
  for general mesh connectivity is documented but not automated yet.
