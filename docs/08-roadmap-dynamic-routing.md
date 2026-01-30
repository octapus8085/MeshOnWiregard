# Roadmap: Dynamic Routing (Babel / OSPF / BGP)

## Phase 2: Hub selection and telemetry

- Add latency probes to select the best hub per spoke.
- Health-check hubs with WireGuard handshake age + ping.
- Extend `wg-exit-selector` patterns for hub selection.

## Phase 3: Dynamic routing integration

### Option A: Babel

- Lightweight, handles mesh networks well.
- Integrate with `babeld` on hubs for spoke route propagation.
- Keep WireGuard AllowedIPs as `/32` per node; Babel handles overlay routing.

### Option B: OSPF (via FRR)

- Standard enterprise routing protocol.
- Useful when the mesh overlays data-center networks.
- Requires more configuration and monitoring.

### Option C: BGP (via FRR or BIRD)

- For large deployments and multi-region routing.
- Can advertise mesh prefixes to internal routers.

## Implementation path

1. **Keep v1 simple**: static peers, no dynamic protocol.
2. **Add a routing daemon toggle** in the inventory (`routing_protocol = babel|ospf|bgp`).
3. **Generate per-node configs** for the chosen daemon (systemd units + configs).
4. **Document convergence testing** and rollback steps.
