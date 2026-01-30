# Migration guide: full mesh → star

This guide migrates a full mesh inventory to a star topology with one or more
hubs.

## Step 1: Choose your hub(s)

Pick the node(s) that will act as hubs. Hubs should have stable connectivity and
be able to enable IP forwarding.

## Step 2: Add mesh topology fields

```ini
[mesh]
mesh_cidr = 10.40.0.0/24
topology = star
hubs = alpha
hub_selection = static
```

## Step 3: Ensure hub forwarding is allowed

For each hub node, confirm:

- `forwarding = true` is set (optional, generator adds forwarding for hubs in
  star mode, but this documents intent).
- Firewall allows `wg0` → `wg0` forwarding.

## Step 4: Regenerate and apply configs

```bash
./wgmesh.sh validate -c mesh.local.conf
./wgmesh.sh gen -c mesh.local.conf -o ./out
sudo ./wgmesh.sh apply -c mesh.local.conf -o ./out --node alpha
```

## Step 5: Verify spoke peer lists

Spokes should peer **only** with hubs. Hubs peer with all nodes.

```bash
wg show wg0 peers
```

## Step 6: Re-evaluate failover

- If there is only one hub, `wg-failover` is typically unnecessary.
- If there are multiple hubs, leave the service installed but note that
  **automatic hub selection is not implemented in v1**.
