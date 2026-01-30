# Inventory spec (`mesh.conf`)

The inventory is an INI-style file with a `[mesh]` section and one or more
`[node "name"]` sections. The generator is case-insensitive for section names
and keys, but **values are case-sensitive**.

## `[mesh]` fields

| Field | Required | Description |
| --- | --- | --- |
| `interface` | yes | WireGuard interface name (e.g., `wg0`). |
| `port` | no | Listen port (default `51820`). |
| `dns` | no | DNS server(s) for generated configs. |
| `mesh_cidr` | yes | RFC1918 mesh subnet (e.g., `10.40.0.0/24`). Used for policy routing exclusions. |
| `topology` | no | `fullmesh` (default) or `star`. |
| `hubs` | no | Comma-separated hub node names (required for `topology=star`). |
| `hub_selection` | no | `static` (default) or `latency` (future). |
| `local_node` | no | Default node name when applying locally. |
| `exit_nodes` | no | Comma-separated exit nodes used for internet egress. |
| `exit_primary` | no | Default exit node (if using manual selection). |
| `exit_policy` | no | `latency` or `manual`. |
| `exit_check_interval_seconds` | no | Selector interval (required for exit routing). |
| `exit_test_target` | no | Optional IP for exit health checks. |
| `enable_exit_for_nodes` | no | Comma-separated nodes or `all`. |

## `[node "name"]` fields

| Field | Required | Description |
| --- | --- | --- |
| `address` | yes | Node address in CIDR (e.g., `10.40.0.1/32`). |
| `endpoint` | yes | Hostname/IP + port for the node. |
| `allowed_ips` | yes | Comma-separated AllowedIPs advertised by the node. |
| `public_key` | yes* | Public key; required unless using `--gen-keys` or a local private key. |
| `private_key` | no | Inline private key. |
| `private_key_path` | no | Path to private key file (default `/etc/wireguard/<iface>.key`). |
| `persistent_keepalive` | no | Persistent keepalive interval in seconds. |
| `endpoint_alt` | no | Alternate endpoint for failover. |
| `ssh_host` | no | SSH host alias for apply-remote. |
| `ssh_user` | no | SSH user override. |
| `ssh_port` | no | SSH port override. |
| `forwarding` | no | `true` to enable IPv4 forwarding in PostUp. |
| `nat_iface` | no | Interface for MASQUERADE + forward rules. |
| `exit_out_iface` | no | Required on exit nodes for NAT. |
| `enable_nat` | no | `true` on exit nodes to enable MASQUERADE. |
| `post_up` | no | Extra PostUp commands appended after defaults. |
| `post_down` | no | Extra PostDown commands appended after defaults. |

\* `public_key` can be generated if you supply `private_key_path` and run
`--gen-keys` or `gen-keys`.

## Example (star topology)

```ini
[mesh]
interface = wg0
port = 51820
dns = 1.1.1.1
mesh_cidr = 10.40.0.0/24
topology = star
hubs = alpha
hub_selection = static
exit_nodes = alpha
exit_check_interval_seconds = 20
enable_exit_for_nodes = all

[node "alpha"]
address = 10.40.0.1/32
endpoint = alpha.example.com:51820
allowed_ips = 10.40.0.1/32
public_key = <ALPHA_PUBLIC_KEY>
private_key = <ALPHA_PRIVATE_KEY>
exit_out_iface = eth0
enable_nat = true

[node "bravo"]
address = 10.40.0.2/32
endpoint = bravo.example.com:51820
allowed_ips = 10.40.0.2/32
public_key = <BRAVO_PUBLIC_KEY>
private_key = <BRAVO_PRIVATE_KEY>

[node "charlie"]
address = 10.40.0.3/32
endpoint = charlie.example.com:51820
allowed_ips = 10.40.0.3/32
public_key = <CHARLIE_PUBLIC_KEY>
private_key = <CHARLIE_PRIVATE_KEY>
```

## Example (full mesh)

```ini
[mesh]
interface = wg0
mesh_cidr = 10.40.0.0/24

[node "alpha"]
address = 10.40.0.1/32
endpoint = alpha.example.com:51820
allowed_ips = 10.40.0.1/32
public_key = <ALPHA_PUBLIC_KEY>
private_key = <ALPHA_PRIVATE_KEY>

[node "bravo"]
address = 10.40.0.2/32
endpoint = bravo.example.com:51820
allowed_ips = 10.40.0.2/32
public_key = <BRAVO_PUBLIC_KEY>
private_key = <BRAVO_PRIVATE_KEY>
```
