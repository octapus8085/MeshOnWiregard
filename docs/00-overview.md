# MeshOnWiregard Docs Overview

## Purpose
MeshOnWiregard is a lightweight inventory-driven generator for WireGuard configs and helper services (failover + exit selector). The v1 goal is predictable connectivity with minimal moving parts, targeting Ubuntu 22.04/24.04. This documentation standardizes the operational model so the project aligns with real-world needs and avoids common routing conflicts.

## What changed in this refactor
- **Docs-first workflow:** The repo now contains a structured `docs/` directory that acts as the primary wiki.
- **Topology awareness:** Supports both **full-mesh** and **star** (hub/spoke), with star recommended for most deployments.
- **Policy routing consistency:** Standard fwmarks/tables avoid conflicts with Tailscale marks.
- **Private IP plan:** Mesh IPs use RFC1918 (IPv4) and optional ULA (IPv6).
- **Idempotent routing hooks:** All PostUp/PostDown commands are safe to re-run.

## Directory map
- `docs/00-overview.md` — This overview.
- `docs/01-inventory-spec.md` — Mesh inventory schema + examples.
- `docs/02-topologies.md` — Full-mesh vs star topology.
- `docs/03-routing-fwmark.md` — Policy routing, marks, tables, exclusions.
- `docs/04-exit-routing.md` — Optional internet exit routing.
- `docs/05-troubleshooting.md` — Diagnostics and common commands.
- `docs/06-migration-guide.md` — Move from full mesh to star.
- `docs/07-security.md` — Keys, permissions, firewall, sysctl.
- `docs/08-roadmap-dynamic-routing.md` — Future routing roadmap.
- `docs/09-tasks.md` — Phased work plan + acceptance criteria.

## Quick start
1. Review `docs/01-inventory-spec.md` for the new `mesh.conf` schema.
2. Decide on topology in `docs/02-topologies.md` (star is recommended).
3. Confirm routing behavior in `docs/03-routing-fwmark.md`.
4. Use `wgmesh.sh validate` and `wgmesh.sh gen` as before.

## Optional mkdocs
A minimal `mkdocs.yml` is included. You can host the docs via GitHub Pages or any mkdocs-friendly pipeline.
