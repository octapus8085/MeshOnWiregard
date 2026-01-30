# Inventory Spec (mesh.conf)

The inventory is INI-style with `[mesh]` global settings and multiple `[node "name"]` sections. Fields are case-insensitive and values are trimmed.

## [mesh] section

| Field | Required | Description |
| --- | --- | --- |
| `interface` | yes | WireGuard interface name (ex: `wg0`). |
| `port` | no | Listen port (default `51820`). |
| `dns` | no | DNS server(s) to push to peers in the generated configs. |
| `mesh_cidr` | yes | Mesh CIDR. **Must be RFC1918 or ULA**. Example: `10.40.0.0/24` or `fd00:40::/64`. |
| `topology` | no | `fullmesh` (default) or `star`. |
| `hubs` | required when `topology=star` | Comma-separated hub node names. |
| `hub_selection` | no | `static` (default) or `latency` (future). |
| `local_node` | no | Node name to treat as local host for `apply`. |
| `exit_nodes` | optional | Comma-separated list of exit-capable node names. |
| `exit_primary` | optional | Preferred exit node in manual mode. |
| `exit_policy` | optional | `latency` or `manual`. |
| `exit_check_interval_seconds` | optional | Timer interval for exit selector. |
| `exit_test_target` | optional | IP to ping for exit diagnostics. |
| `enable_exit_for_nodes` | optional | Comma-separated node names or `all`. |

### Per-node optional fields (in `[node "name"]`)

| Field | Required | Description |
| --- | --- | --- |
| `address` | yes | WireGuard IP (CIDR) for the node. |
| `endpoint` | yes | Endpoint hostname/IP + port. |
| `allowed_ips` | yes | Comma-separated list of AllowedIPs for the peer. Typically `/32` per node. |
| `public_key` | yes | WireGuard public key. Required unless `--gen-keys` is used. |
| `private_key` | no | Optional private key for generating configs. |
| `private_key_path` | no | File path to private key. Used for key generation/lookup. |
| `endpoint_alt` | no | Optional secondary endpoint for failover. |
| `persistent_keepalive` | no | Keepalive interval (seconds). |
| `ssh_host` | no | SSH host alias or hostname for `apply-remote`. |
| `ssh_user` | no | SSH username override for `apply-remote`. |
| `ssh_port` | no | SSH port override for `apply-remote`. |
| `forwarding` | no | `true/false` - enable IPv4 forwarding on this node. |
| `nat_iface` | no | Egress interface for generic NAT (iptables MASQUERADE). |
| `post_up` | no | Extra PostUp commands (appended). |
| `post_down` | no | Extra PostDown commands (appended). |
| `exit_out_iface` | required for exit nodes | Egress interface name for exit routing NAT. |
| `enable_nat` | required for exit nodes | Must be `true` for exit nodes. |

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
```

## Example (star topology)

```ini
[mesh]
interface = wg0
topology = star
hubs = alpha
hub_selection = static
mesh_cidr = 10.40.0.0/24

[node "alpha"]
address = 10.40.0.1/32
endpoint = alpha.example.com:51820
allowed_ips = 10.40.0.1/32
public_key = <ALPHA_PUBLIC_KEY>
forwarding = true

[node "bravo"]
address = 10.40.0.2/32
endpoint = bravo.example.com:51820
allowed_ips = 10.40.0.2/32
public_key = <BRAVO_PUBLIC_KEY>
```

## Validation rules

- `mesh_cidr` is required and must be RFC1918 or ULA.
- IPv4 node addresses must be RFC1918 **and** within `mesh_cidr`.
- `topology=star` requires at least one hub name defined in `hubs`.
- Exit routing fields require `exit_nodes`, `enable_exit_for_nodes`, and `exit_check_interval_seconds`.
