# MeshOnWiregard

This repo provides a minimal inventory-driven workflow for generating WireGuard mesh configs and a failover helper to swap peer endpoints when the primary host is unreachable.

## Files

- `wgmesh.sh`: Inventory-aware helper script with `validate`, `gen`, `install-failover`, and `apply` subcommands.
- `wgmesh.sh`: Also includes `apply-remote` to install configs over SSH using your local SSH config.
- `mesh.conf`: Example inventory format.
- `usr/local/bin/wg-failover`: Template failover helper script.
- `wg-failover.service`: systemd unit for the failover check.
- `wg-failover.timer`: systemd timer for periodic failover checks.

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
7. **Enable the timer**
   ```bash
   sudo systemctl enable --now wg-failover.timer
   ```
8. **Verify status**
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

## Validation behavior

`wgmesh.sh validate` will:

- Confirm the mesh interface is set.
- Confirm each node has the required fields.
- Ensure addresses and public keys are unique.
- Validate CIDR formatting and endpoint formats.
- Print a summary inventory.

## Failover behavior

- `wgmesh.sh gen` writes a `wg-failover.conf` file in the output directory.
- `wgmesh.sh apply` installs that file to `/etc/wireguard/wg-failover.conf`.
- The `wg-failover` script checks the primary endpoint hostname reachability using `ping`.
- If the primary host is unreachable and a secondary is reachable, it updates a single peer endpoint via `wg set` per run.
- When the primary becomes reachable again, it restores that peer on a subsequent run (one peer at a time).

If a node does **not** define `endpoint_alt`, no automatic failover is possible
for that peer.

## Tailscale / endpoint guidance

- If you want WireGuard to ride on **public IPs**, set `endpoint` to the public
  IP/hostname and use `endpoint_alt` for a backup public address (if available).
- If your servers are behind NAT or you manage them over Tailscale, you can use
  Tailscale IPs/hostnames for `endpoint` and `endpoint_alt`. The failover check
  still relies on ICMP reachability (`ping`) to those endpoints.
- It is valid to keep management/SSH over Tailscale but keep WireGuard
  endpoints on public IPs for data-plane traffic.
