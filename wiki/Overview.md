# MeshOnWiregard Overview

MeshOnWiregard is an inventory-driven generator for WireGuard configurations.
It targets Ubuntu 22.04/24.04 and uses Bash only. The inventory (`mesh.conf`)
controls topology, addressing, and optional exit routing behavior.

## Documentation index

- **Inventory spec**: `docs/01-inventory-spec.md`
- **Topologies (full mesh vs star)**: `docs/02-topologies.md`
- **Routing + fwmark policy**: `docs/03-routing-fwmark.md`
- **Exit routing**: `docs/04-exit-routing.md`
- **Troubleshooting**: `docs/05-troubleshooting.md`
- **Migration guide**: `docs/06-migration-guide.md`
- **Security**: `docs/07-security.md`
- **Dynamic routing roadmap**: `docs/08-roadmap-dynamic-routing.md`
- **Tasks / phases**: `docs/09-tasks.md`

## Design goals

- **Operational clarity**: treat the inventory as a source of truth.
- **Safe addressing**: use RFC1918 for IPv4 and ULA for IPv6.
- **Topology flexibility**: full mesh for legacy, star for recommended scale.
- **Predictable routing**: consistent marks and routing tables.
- **Idempotent lifecycle**: PostUp/PostDown are reversible.

## Recommended defaults

- **Topology**: `star` (hub/spoke), unless you need full mesh.
- **Addressing**: RFC1918 (e.g., `10.40.0.0/24`) or ULA for IPv6.
- **Policy routing**: `Table = off` when policy routing is in use.

## Quick start

```bash
cp mesh.conf mesh.local.conf
$EDITOR mesh.local.conf
./wgmesh.sh validate -c mesh.local.conf
./wgmesh.sh gen -c mesh.local.conf -o ./out
```
