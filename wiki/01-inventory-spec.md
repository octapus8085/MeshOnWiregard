# Inventory specification (`mesh.conf`)

The inventory is an INI-style file with a single `[mesh]` section and one or
more `[node "name"]` sections. All values are strings.

## `[mesh]` fields

Required:

- `interface`: WireGuard interface name (e.g., `wg0`).

Recommended:

- `mesh_cidr`: RFC1918 IPv4 (or ULA IPv6) CIDR for the mesh (e.g., `10.40.0.0/24`).

Optional:

- `port`: listen port (default: `51820`).
- `dns`: DNS servers for clients.
- `local_node`: node name used by `apply` when `--node` is not provided.
- `topology`: `fullmesh` (default) or `star`.
- `hubs`: comma-separated hub node names (required when `topology=star`).
- `hub_selection`: `static` or `latency` (v1 uses `static`; `latency` is planned).

Exit routing (optional):

- `exit_nodes`: comma-separated list of nodes that can provide internet exit.
- `exit_primary`: default exit node when `exit_policy=manual`.
- `exit_policy`: `latency` or `manual`.
- `exit_check_interval_seconds`: timer interval for exit selector.
- `exit_test_target`: optional test IP for diagnostics.
- `enable_exit_for_nodes`: comma-separated list of nodes or `all`.

## `[node "name"]` fields

Required:

- `address`: node WireGuard address (CIDR). Use RFC1918 IPv4 or ULA IPv6.
- `endpoint`: public endpoint (`host:port` or `[v6]:port`).
- `allowed_ips`: comma-separated list of CIDRs (typically the node address `/32`).
- `public_key`: WireGuard public key (required unless `--gen-keys`).

Optional:

- `private_key`: inline private key (optional).
- `private_key_path`: path to a private key file.
- `endpoint_alt`: optional failover endpoint.
- `persistent_keepalive`: keepalive seconds for NAT traversal.
- `ssh_host`: host/alias for `apply-remote` (defaults to node name).
- `ssh_user`: SSH username.
- `ssh_port`: SSH port.
- `forwarding`: `true|false` to set `net.ipv4.ip_forward` in PostUp.
- `nat_iface`: interface name for MASQUERADE + forward rules.
- `post_up`: extra PostUp commands.
- `post_down`: extra PostDown commands.

Exit node fields (when listed in `exit_nodes`):

- `exit_out_iface`: outbound interface (e.g., `eth0`).
- `enable_nat`: `true` to enable MASQUERADE + forward rules.

## Example (star topology)

```ini
[mesh]
interface = wg0
mesh_cidr = 10.40.0.0/24
topology = star
hubs = alpha
hub_selection = static

[node "alpha"]
address = 10.40.0.1/32
endpoint = alpha.example.com:51820
public_key = <ALPHA_PUBLIC_KEY>
allowed_ips = 10.40.0.1/32
forwarding = true

[node "bravo"]
address = 10.40.0.2/32
endpoint = bravo.example.com:51820
public_key = <BRAVO_PUBLIC_KEY>
allowed_ips = 10.40.0.2/32
```

## Example (exit routing snippet)

```ini
[mesh]
exit_nodes = charlie,sierra
exit_primary = charlie
exit_policy = latency
exit_check_interval_seconds = 20
enable_exit_for_nodes = all

[node "charlie"]
exit_out_iface = eth0
enable_nat = true
```
