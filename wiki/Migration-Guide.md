# Migration: full mesh to star

This guide migrates a full mesh to a hub/spoke (star) topology without
breaking existing nodes.

## 1) Add mesh CIDR

Define a private mesh CIDR (RFC1918 or ULA):

```ini
[mesh]
mesh_cidr = 10.40.0.0/24
```

## 2) Choose hubs

Pick one or more hubs and add topology fields:

```ini
[mesh]
topology = star
hubs = alpha
hub_selection = static
```

## 3) Enable forwarding on hubs

Hubs should forward traffic between spokes. The generator will add forwarding
rules, but ensure your host firewall allows `wg0 -> wg0` forwarding.

## 4) Regenerate configs

```bash
./wgmesh.sh validate -c mesh.local.conf
./wgmesh.sh gen -c mesh.local.conf -o ./out
```

## 5) Roll out

Apply hub configs first, then spokes:

```bash
sudo ./wgmesh.sh apply -c mesh.local.conf -o ./out --node alpha
sudo ./wgmesh.sh apply -c mesh.local.conf -o ./out --node bravo
```

## 6) Optional: exit routing

If exit routing is enabled, confirm `mesh_cidr` is set and policy routing is
installed (`ip rule show`, `ip route show table 101`).

## Backward compatibility

If you omit `topology`, `fullmesh` remains the default.
