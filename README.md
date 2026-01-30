# MeshOnWiregard

This repo provides a minimal inventory-driven workflow for generating WireGuard mesh configs and a failover helper to swap peer endpoints when the primary host is unreachable. It now includes a docs set covering topologies, routing marks, and operational guidance in `docs/`.

## Files

- `wgmesh.sh`: Inventory-aware helper script with `validate`, `gen`, `install-failover`, and `apply` subcommands.
- `wgmesh.sh`: Also includes `apply-remote` to install configs over SSH using your local SSH config.
- `mesh.conf`: Example inventory format.
- `usr/local/bin/wg-failover`: Template failover helper script.
- `wg-failover.service`: systemd unit for the failover check.
- `wg-failover.timer`: systemd timer for periodic failover checks.
- `usr/local/bin/wg-exit-selector`: Exit selector helper for smart egress routing.
- `wg-exit-selector.service`: systemd unit for the exit selector.
- `wg-exit-selector.timer`: systemd timer for periodic exit selection.
- `docs/`: Operational documentation and migration guides.
- `mkdocs.yml`: Optional MkDocs config for GitHub Pages.

## Documentation

Start here:

- [Overview](docs/00-overview.md)
- [Inventory spec](docs/01-inventory-spec.md)
- [Topologies (full mesh vs star)](docs/02-topologies.md)
- [Routing & fwmark policy](docs/03-routing-fwmark.md)
- [Exit routing](docs/04-exit-routing.md)
- [Troubleshooting](docs/05-troubleshooting.md)
- [Migration guide](docs/06-migration-guide.md)
- [Security](docs/07-security.md)
- [Dynamic routing roadmap](docs/08-roadmap-dynamic-routing.md)
- [Tasks & acceptance criteria](docs/09-tasks.md)

## Usage steps (exact)

1. **Copy and edit the inventory**
   ```bash
   cp mesh.conf mesh.local.conf
   $EDITOR mesh.local.conf
   ```
2. **Validate the inventory**
   ```bash
   ./wgmesh.sh validate -c mesh.local.conf
   ```
3. **Generate configs**
   ```bash
   ./wgmesh.sh gen -c mesh.local.conf -o ./out
   ```
   If you want the tool to generate missing keypairs locally:
   ```bash
   ./wgmesh.sh gen -c mesh.local.conf -o ./out --gen-keys
   ```
4. **Install the config on a node**
   ```bash
   sudo ./wgmesh.sh apply -c mesh.local.conf -o ./out --node alpha
   ```
   Or set `local_node` in `[mesh]` and omit `--node`.
5. **Install configs remotely over SSH**
   ```bash
   ./wgmesh.sh apply-remote -c mesh.local.conf -o ./out --all
   ```
   This also installs the failover helper and systemd units on the remote host.
   If your remote `sudo` requires a TTY (common with `requiretty`), add:
   ```bash
   ./wgmesh.sh apply-remote -c mesh.local.conf -o ./out --all --ssh-tty
   ```
   You can combine with `--gen-keys` to generate missing keypairs locally before pushing.
   If you need to generate keys and persist them back into the inventory:
   ```bash
   ./wgmesh.sh gen-keys -c mesh.local.conf -o ./out
   ```
6. **Install the failover helper and systemd units**
   ```bash
   sudo ./wgmesh.sh install-failover
   ```
7. **Install the exit selector (optional, for exit routing)**
   ```bash
   sudo ./wgmesh.sh install-exit-selector -c mesh.local.conf
   sudo systemctl enable --now wg-exit-selector.timer
   ```
8. **Enable the timer**
   ```bash
   sudo systemctl enable --now wg-failover.timer
   ```
9. **Verify status**
   ```bash
   sudo systemctl status wg-quick@wg0.service
   sudo systemctl status wg-failover.timer
   ```

## OS prerequisites

### Ubuntu (systemd)

Install WireGuard tools and ensure systemd is available:

```bash
sudo apt-get update
sudo apt-get install -y wireguard wireguard-tools
```

The `apply` and `install-failover` commands are designed for Linux hosts with
systemd. They install configs under `/etc/wireguard` and manage services via
`systemctl`.

### macOS (local generation + manual import)

macOS is supported for generating configs and manually importing them into the
WireGuard app. Install the tools with Homebrew:

```bash
brew install wireguard-tools
```

Generate configs on macOS and then:

- Import `<node>.conf` into the WireGuard app, **or**
- Use `wg-quick up <path-to-conf>` if you have `wg-quick` available.

The `install-failover` and `apply` commands assume systemd and are not intended
for macOS.

## Inventory requirements

- `[mesh]` must include `interface` (e.g., `wg0`).
- `[mesh]` must include `mesh_cidr` (RFC1918 or ULA), for example `10.40.0.0/24`.
- `[mesh]` may include `topology = star` with `hubs = alpha,charlie` to enable hub/spoke behavior.
- `[mesh]` can include `local_node` to indicate which `[node]` entry refers to
  the current host (used as a default for `apply` when `--node` is omitted).
- Each `[node "name"]` entry must include:
  - `address` (CIDR), `endpoint`, and `allowed_ips`.
  - `public_key` is required unless you run with `--gen-keys` and provide a writable `private_key_path` (or allow keys to be generated under `out/keys`).
- Optional SSH fields (used by `apply-remote`):
  - `ssh_host` (defaults to the node name, supports SSH config aliases),
  - `ssh_user` (optional override user),
  - `ssh_port` (optional port override; otherwise SSH config is used).
- `endpoint_alt` is optional but recommended for failover.
- `private_key` or `private_key_path` can be provided to embed the key when generating configs.
  - With `--gen-keys`, missing keys are generated with `wg genkey` and public keys are derived with `wg pubkey`.
  - With `gen-keys`, missing keys are generated and written back into the inventory file.
- `allowed_ips` may be a comma-delimited list of CIDRs.
- Optional exit-routing mesh fields (for smart internet forwarding):
  - `exit_nodes` (comma-delimited list of exit-capable nodes),
  - `exit_primary` (optional default exit node),
  - `exit_policy` (`latency` or `manual`),
  - `exit_check_interval_seconds` (timer interval),
  - `exit_test_target` (optional IP for diagnostics),
  - `enable_exit_for_nodes` (comma-delimited list of nodes or `all`).
- Exit-node fields:
  - `exit_out_iface` (egress interface name),
  - `enable_nat` (set `true` to enable MASQUERADE + forwarding rules).

## Validation behavior

`wgmesh.sh validate` will:

- Confirm the mesh interface is set.
- Confirm each node has the required fields.
- Ensure addresses and public keys are unique.
- Validate CIDR formatting and endpoint formats.
- Validate exit routing settings (exit nodes, policy, NAT interface, timer interval).
- Print a summary inventory.

## Failover behavior

- `wgmesh.sh gen` writes a `wg-failover.conf` file in the output directory.
- `wgmesh.sh apply` installs that file to `/etc/wireguard/wg-failover.conf`.
- The `wg-failover` script checks the primary endpoint hostname reachability using `ping`.
- If the primary host is unreachable and a secondary is reachable, it updates a single peer endpoint via `wg set` per run.
- When the primary becomes reachable again, it restores that peer on a subsequent run (one peer at a time).

If a node does **not** define `endpoint_alt`, no automatic failover is possible
for that peer.

## Smart exit routing (full mesh)

This repo can keep full-mesh connectivity intact while forwarding **internet
traffic** through the cheapest/closest exit node. Mesh peer `AllowedIPs` remain
`/32` addresses, and the exit default route (`0.0.0.0/0`) is applied dynamically
by a selector service so only **one exit** is active at a time.

### Inventory snippet

```ini
[mesh]
exit_nodes = charlie,sierra
exit_primary = charlie
exit_policy = latency
exit_check_interval_seconds = 20
exit_test_target = 1.1.1.1
enable_exit_for_nodes = all

[node "charlie"]
exit_out_iface = eth0
enable_nat = true

[node "sierra"]
exit_out_iface = ens3
enable_nat = true
```

### Behavior

- **Exit nodes** get generated `PostUp`/`PostDown` commands that enable
  `net.ipv4.ip_forward=1` and add iptables `FORWARD` + `MASQUERADE` rules on the
  configured `exit_out_iface`.
- **Exit-enabled nodes** get:
  - `Table = off` to prevent wg-quick from managing routes.
  - Policy routing in table `101`:
    - mark non-mesh traffic with `fwmark 0x101`,
    - `ip rule` sends the marked traffic to table `101`,
    - `ip route` adds a default route via `wg0` in table `101`,
    - mesh CIDR and RFC1918 destinations are excluded from marking.
- The **wg-exit-selector** service:
  - measures reachability using WireGuard handshakes and ping to exit WG IPs,
  - selects the lowest-latency reachable exit (or `exit_primary` in manual mode),
  - updates `AllowedIPs` so only one exit peer carries `0.0.0.0/0`.
  - reports the optional `exit_test_target` in `wg-exit-selector status`.

### Install/enable

`apply` and `apply-remote` will install the exit selector on nodes listed in
`enable_exit_for_nodes`. You can also install it directly:

```bash
sudo ./wgmesh.sh install-exit-selector -c mesh.local.conf
sudo systemctl enable --now wg-exit-selector.timer
```

### Manual override

Create `/etc/wireguard/exit.override` with the exit node name (e.g. `charlie`)
to force a specific exit.

### Verify

```bash
ip rule show
ip route show table 100
wg show wg0 allowed-ips
./wgmesh.sh exit-status
sudo wg-exit-selector status
curl ifconfig.me
```

**Limitations:** only one exit peer should advertise `0.0.0.0/0` at a time; the
selector enforces that while keeping full-mesh peer connectivity unchanged.

## Policy-based routing for star (hub-and-spoke) topologies

Yes—WireGuard supports a **star (hub-and-spoke) topology**. Each spoke peers with
one or more hubs, and the hubs forward traffic between spokes or out to the
internet. To make this work reliably, you typically:

- Allow the hub(s) to advertise the destination networks via `allowed_ips`.
- Enable IP forwarding (and NAT if the hub provides internet egress).
- Use policy routing on spokes when only *some* traffic should traverse the hub.

If you want spokes to forward **internet traffic** or a **closest/private network**
through a preferred hub (e.g., try `charlie`, fall back to `bravo`), combine
WireGuard allowed IPs with Linux policy routing:

1. **Advertise hub egress in the inventory** so spokes can route to it.
   For example, in `mesh.conf`, give the hub peers `allowed_ips` that include
   internet/default routes and/or private networks you want to reach:
   ```ini
   [node "charlie"]
   allowed_ips = 0.0.0.0/0, ::/0, 10.10.0.0/16

   [node "bravo"]
   allowed_ips = 0.0.0.0/0, ::/0, 10.10.0.0/16
   ```
2. **Add policy routing rules** on each spoke so only select sources use the hub.
   Example: route a LAN behind the spoke (`192.168.50.0/24`) through the hub while
   keeping the host’s own traffic local:
   ```bash
   # Use table 100 for hub egress.
   sudo ip rule add from 192.168.50.0/24 table 100
   # Prefer charlie as default in table 100.
   sudo ip route replace default via 10.0.0.3 dev wg0 table 100
   ```
3. **Add a simple failover hook** to prefer `charlie` but fall back to `bravo`.
   A lightweight timer or cron job can update the route based on reachability:
   ```bash
   # If charlie is reachable, keep it as the egress.
   if ping -c1 -W1 10.0.0.3 >/dev/null 2>&1; then
     sudo ip route replace default via 10.0.0.3 dev wg0 table 100
   else
     sudo ip route replace default via 10.0.0.2 dev wg0 table 100
   fi
   ```

4. **Use PostUp/PostDown hooks for hubs (iptables + forwarding).** `wgmesh.sh`
   can generate these automatically per node when you set `forwarding` and
   `nat_iface` in `mesh.conf`:
   ```ini
   [node "charlie"]
   # Hub node: enable forwarding and NAT out eth0.
   forwarding = true
   nat_iface = eth0

   [node "alpha"]
   # Spoke node: optional routing policy for a LAN behind the spoke.
   post_up = ip rule add from 192.168.50.0/24 table 100; ip route replace default via 10.40.0.3 dev %i table 100
   post_down = ip rule del from 192.168.50.0/24 table 100; ip route del default via 10.40.0.3 dev %i table 100
   ```
   This emits valid `PostUp`/`PostDown` lines in each generated config. Hub
   nodes get `sysctl -w net.ipv4.ip_forward=1` plus iptables forward/NAT rules,
   and any `post_up`/`post_down` you set are appended after those defaults.

This keeps your mesh fully connected while steering only selected traffic through
the “closest” hub and failing over automatically if the preferred hub drops.

**Hub prerequisites:** ensure forwarding is enabled and NAT is configured when
acting as an internet gateway. Example (Linux):
```bash
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```

## Tailscale / endpoint guidance

- If you want WireGuard to ride on **public IPs**, set `endpoint` to the public
  IP/hostname and use `endpoint_alt` for a backup public address (if available).
- If your servers are behind NAT or you manage them over Tailscale, you can use
  Tailscale IPs/hostnames for `endpoint` and `endpoint_alt`. The failover check
  still relies on ICMP reachability (`ping`) to those endpoints.
- It is valid to keep management/SSH over Tailscale but keep WireGuard
  endpoints on public IPs for data-plane traffic.
