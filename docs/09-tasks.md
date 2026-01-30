# Tasks & acceptance criteria

This document breaks the refactor into phases with acceptance criteria.

## Phase 1 (v1): docs, marks/tables, IP plan, star generator

### Scope

- Document operational workflows in `docs/`.
- Standardize routing marks/tables and exclusions.
- Enforce RFC1918 (and optional ULA for v6).
- Add star topology generation.

### Acceptance criteria

- [ ] `docs/` contains the required markdown pages.
- [ ] `README.md` links to the docs and summarizes key changes.
- [ ] `wgmesh.sh` defines `MARK_EXIT=0x101`, `TABLE_EXIT=101`,
      `MARK_MESH_BYPASS=0x102`, and validates Tailscale conflicts.
- [ ] `wgmesh.sh` rejects public IPv4 ranges (e.g., `172.50.0.0/24`).
- [ ] Exit routing uses `mesh_cidr` exclusions (no per-IP `/32` loops).
- [ ] `topology=star` generates hub/spoke peering correctly.
- [ ] PostUp/PostDown are idempotent.

## Phase 2: hub selection and dynamic routing prep

### Scope

- Implement `hub_selection=latency` selector.
- Add health checks and improved hub failover logic.
- Introduce optional metrics export for hub health.

### Acceptance criteria

- [ ] Spokes can auto-select the lowest-latency hub.
- [ ] Selector respects manual overrides when configured.
- [ ] Config output remains stable when `hub_selection=static`.

## Phase 3: dynamic routing (BGP/OSPF/Babel)

### Scope

- Integrate Babel/OSPF/BGP using FRR or babeld.
- Support route filtering to avoid leaking public prefixes.

### Acceptance criteria

- [ ] Dynamic routing can be enabled per hub.
- [ ] Mesh routes are learned automatically without static `AllowedIPs` changes.
- [ ] Exit routing remains compatible with policy routing rules.
