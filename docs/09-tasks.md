# Tasks and phases

## Phase 1 (v1)

Scope: docs, marks/tables, IP plan enforcement, star generator.

**Checklist**
- [ ] Docs in `docs/` with topology, routing, exit routing, and migration guide.
- [ ] Standardized marks/tables (`MARK_EXIT=0x101`, `TABLE_EXIT=101`).
- [ ] IP plan validation (RFC1918/ULA) with `mesh_cidr`.
- [ ] Star topology generation with hub forwarding.

**Acceptance criteria**
- `wgmesh.sh validate` fails on public IPv4 ranges.
- Exit routing rules exclude `mesh_cidr`, RFC1918, loopback, and Tailscale CIDR.
- `topology=star` generates spoke-only hub peer sets.

## Phase 2 (planning)

Scope: hub selection (latency) and dynamic routing groundwork.

**Checklist**
- [ ] Add `hub_selection=latency` implementation.
- [ ] Emit hub selector config/service (optional).
- [ ] Define routing daemon configuration schema (Babel/OSPF/BGP).

**Acceptance criteria**
- Latency-based hub selection chooses a reachable hub.
- Routing daemon config is generated but optional, off by default.

## Phase 3 (future)

Scope: BGP/OSPF/Babel integration.

**Checklist**
- [ ] Implement daemon templates and systemd units.
- [ ] Add docs for each routing mode.
- [ ] Provide safe defaults to prevent route leaks.

**Acceptance criteria**
- Each daemon can be enabled per node without breaking static routing.
