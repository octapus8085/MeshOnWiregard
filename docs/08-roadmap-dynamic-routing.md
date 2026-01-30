# Roadmap: dynamic routing

Dynamic routing is out of scope for v1, but the project should be able to grow
into it without major rewrites. This document captures a pragmatic roadmap.

## Phase 2: Smarter hub selection

- Implement latency-based `hub_selection` (ICMP or WG handshake timing).
- Add a small selector similar to `wg-exit-selector`.
- Keep the interface output identical to v1 (only peer selection changes).

## Phase 3: Dynamic routing protocols

### Babel

- Lightweight and friendly for mesh networks.
- Suited for hub/spoke or partial meshes.
- Implementation plan: run `babeld` on hubs and optionally on spokes that need
  multi-path routing.

### OSPF (OSPFv2/OSPFv3)

- Standard for enterprise routing.
- Implementation plan: use FRR on hubs, limit areas to the mesh.

### BGP (iBGP/EVPN)

- Useful for large-scale or multi-region meshes.
- Implementation plan: run FRR on hubs, export only mesh routes, and use route
  maps to avoid leaking internet routes.

## Guardrails

- Keep v1's static configs intact; dynamic routing should be opt-in.
- Continue to avoid mark/table conflicts with other overlay networks.
- Ensure policy routing for exit traffic is still respected.
