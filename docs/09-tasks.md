# Tasks & Acceptance Criteria

## Phase 1 (v1 delivery)

### Docs & wiki structure
- [ ] In-repo docs exist in `docs/` with coverage for topology, routing marks, exit routing, troubleshooting, security, and migration.
- [ ] README links to docs and summarizes the new operational defaults.

**Acceptance criteria**
- Docs files 00–09 exist and are referenced in README.
- Inventory schema includes `mesh_cidr`, `topology`, and `hubs` fields.

### Marks & tables standardization
- [ ] Use non-Tailscale marks (`0x101`, `0x102`) and routing table `101`.
- [ ] Validate mark/table collisions.

**Acceptance criteria**
- `wgmesh.sh validate` fails if marks overlap Tailscale range.
- Policy routing uses the standardized constants everywhere.

### IP plan standardization
- [ ] Enforce RFC1918 or ULA mesh ranges.
- [ ] Reject public ranges like `172.50.0.0/24`.

**Acceptance criteria**
- `wgmesh.sh validate` fails for non-RFC1918 IPv4 mesh CIDRs.
- IPv4 node addresses must be inside `mesh_cidr`.

### Star topology generator
- [ ] Add `topology`/`hubs` fields.
- [ ] Spokes peer only with hubs.
- [ ] Hubs peer with all nodes.
- [ ] Hubs enable forwarding rules.

**Acceptance criteria**
- Generated configs for spokes include only hubs as peers.
- Hubs include all peers and `PostUp` enables forwarding.

## Phase 2

### Hub selection (latency)
- [ ] Add health checks (latency/handshake age) for hubs.
- [ ] Allow per-spoke hub preference override.

**Acceptance criteria**
- Spokes can select best hub based on a defined metric.
- Selection can be overridden via config file.

### Dynamic routing prototyping
- [ ] Prototype Babel integration.
- [ ] Document operational steps and rollback.

**Acceptance criteria**
- Routing daemon runs under systemd with generated config.
- Mesh routes propagate without static routes.

## Phase 3

### BGP/OSPF/Babel production integration
- [ ] Add `routing_protocol` inventory flag.
- [ ] Add templated configs for FRR/BIRD as needed.

**Acceptance criteria**
- Protocol selection generates correct configs and systemd units.
- Deployment docs cover monitoring and failure scenarios.
