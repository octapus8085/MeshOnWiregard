# Overview

MeshOnWiregard is a bash-first inventory and config generator for WireGuard
networks. The goal of the refactor is to align the project with practical
operations: clear topology choices, consistent IP planning, and predictable
policy routing.

## Key decisions in v1

- **Docs-first operations**: All operational guidance lives under `docs/`.
- **Topology options**: Full mesh remains supported, but **star (hub/spoke)** is
  recommended for most deployments.
- **IP plan**: Use **RFC1918** ranges for IPv4 (e.g., `10.40.0.0/24`). Avoid
  public ranges such as `172.50.0.0/24`. Optional IPv6 support should use ULA
  (`fd00::/8`).
- **Policy routing**: Exit routing uses a dedicated fwmark and table to avoid
  collisions with Tailscale marks.
- **Bash-only v1**: The generator remains a bash script targeting Ubuntu 22.04/24.04.

## Recommended starting point

1. Read the inventory spec: [docs/01-inventory-spec.md](01-inventory-spec.md)
2. Choose a topology: [docs/02-topologies.md](02-topologies.md)
3. Review routing/marking plan: [docs/03-routing-fwmark.md](03-routing-fwmark.md)
4. If using exit routing: [docs/04-exit-routing.md](04-exit-routing.md)
5. For migration planning: [docs/06-migration-guide.md](06-migration-guide.md)

## What v1 does not attempt

- Dynamic routing (BGP/OSPF/Babel) is **future work**, tracked in
  [docs/08-roadmap-dynamic-routing.md](08-roadmap-dynamic-routing.md).
- Latency-based hub selection is documented but not implemented in v1.
