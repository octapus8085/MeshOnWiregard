# Tasks & Phases

## Phase 1: Core refactor (v1)
**Goals**
- Docs/wiki in-repo.
- Standard marks/tables.
- RFC1918/ULA IP plan enforcement.
- Star topology support.

**Checklist**
- [ ] `docs/` created with operational guides.
- [ ] `README` points to docs and summarizes behavior.
- [ ] `wgmesh.sh` uses standard fwmarks/tables.
- [ ] Validation rejects public IP ranges for mesh addresses.
- [ ] `mesh_cidr` required for exit routing and used for exclusions.
- [ ] Star topology generation supports hubs/spokes.
- [ ] PostUp/PostDown are idempotent.

**Acceptance criteria**
- `wgmesh.sh validate` fails on public ranges and missing `mesh_cidr` for exit routing.
- Spokes only peer with hubs when `topology=star`.
- Hubs peer with all nodes and forward traffic.
- `Table = off` applied for nodes using policy routing.

## Phase 2: Hub selection + routing intelligence
**Goals**
- Latency-based hub selection.
- Multi-hub failover logic.

**Checklist**
- [ ] `hub_selection = latency` implemented in generator and selector.
- [ ] Optional hub override file (similar to exit selector override).
- [ ] Health checks + metrics collection.

**Acceptance criteria**
- Spokes dynamically switch to lowest-latency hub.
- Manual override is possible and persistent.

## Phase 3: Dynamic routing integration
**Goals**
- Babel/OSPF/BGP integration.
- Export mesh CIDR and spoke routes.

**Checklist**
- [ ] FRR/babeld deployment plan documented.
- [ ] Safe import/export policies for mesh routes.
- [ ] Observability (routes, metrics, logs).

**Acceptance criteria**
- Routes between spokes propagate dynamically through hubs.
- Exit selection interacts cleanly with dynamic routing.
