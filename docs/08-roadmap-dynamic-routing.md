# Roadmap: Dynamic Routing (Babel/OSPF/BGP)

This roadmap outlines a future path to add dynamic routing **without overcomplicating v1**.

## Phase 2 goals (post-v1)
- Add hub selection (`hub_selection = latency`) for multi-hub environments.
- Capture RTT/handshake metrics to choose nearest hub.
- Optional automatic hub failover to reduce manual switching.

## Phase 3 goals (dynamic routing integration)

### Option A: Babel
- Lightweight and mesh-friendly.
- Good fit for ad-hoc networks.
- Implementation path:
  1. Package `babeld` on hubs.
  2. Advertise mesh CIDR and spoke routes.
  3. Inject learned routes into `wg0` routes.

### Option B: OSPF
- Predictable, widely understood.
- Good for static infrastructure.
- Implementation path:
  1. Run FRR on hubs.
  2. Use OSPF in a dedicated VRF or table.
  3. Redistribute mesh routes.

### Option C: BGP
- Best for advanced, multi-site topologies.
- Implementation path:
  1. Run FRR/GoBGP on hubs.
  2. Use BGP to export spoke routes.
  3. Inject default routes or exit preferences.

## Design principles
- Keep v1 static and deterministic.
- Add dynamic routing only when hub topology and operational scale demand it.
- Preserve the `mesh.conf` interface as the single source of truth.
