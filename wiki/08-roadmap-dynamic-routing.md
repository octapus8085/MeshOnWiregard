# Roadmap: dynamic routing (Babel/OSPF/BGP)

This is a **future** plan to support dynamic routing while keeping v1
simple and stable.

## Phase 2 (planning)

- Add hub selection (`latency`) for star topology.
- Introduce a routing daemon option per node (opt-in):
  - Babel for small meshes and mesh-friendly convergence.
  - OSPF for enterprise environments.
  - BGP for data center or inter-site routing.

## Phase 3 (implementation)

- Allow per-node routing daemon configuration in `mesh.conf`.
- Generate systemd unit templates for the selected daemon.
- Ensure compatibility with existing WireGuard policy routing.

## Implementation path

1. **Define routing profile** per node (daemon, interfaces, networks).
2. **Generate configs** for the daemon from inventory data.
3. **Validate** route policies to avoid leaking public routes by default.
4. **Document** operational playbooks for each daemon.
