# Inventory Specification (`mesh.conf`)

This document describes the `mesh.conf` schema, fields, and supported options.

## File structure
The inventory uses INI-style sections:

- `[mesh]` — global settings.
- `[node "name"]` — node entries, one per host.

Comments begin with `#` and blank lines are ignored.

## `[mesh]` fields

| Field | Required | Default | Description |
| --- | --- | --- | --- |
| `interface` | ✅ | — | WireGuard interface name (e.g., `wg0`). |
| `port` | ❌ | `51820` | Listen port for the interface. |
| `dns` | ❌ | — | DNS server to inject into generated configs. |
| `local_node` | ❌ | — | Default node name for `apply`. |
| `mesh_cidr` | ✅ (when exit routing enabled) | — | The mesh IPv4/IPv6 CIDR (RFC1918 or ULA). Exit routing requires IPv4. |
| `topology` | ❌ | `fullmesh` | `fullmesh` or `star`. |
| `hubs` | ❌ | — | Comma-separated hub node names (required when `topology=star`). |
| `hub_selection` | ❌ | `static` | `static` or `latency` (latency is future work). |
| `tailscale_iface` | ❌ | — | Optional interface name to bypass marking (typically `tailscale0`). |
| `exit_nodes` | ❌ | — | Comma-separated exit-capable nodes. |
| `exit_primary` | ❌ | — | Default exit node (manual mode). |
| `exit_policy` | ❌ | `latency` | `latency` or `manual`. |
| `exit_check_interval_seconds` | ❌ | — | Exit selector timer interval. |
| `exit_test_target` | ❌ | — | Optional IP for diagnostics. |
| `enable_exit_for_nodes` | ❌ | — | Comma-separated nodes or `all` to enable exit routing. |

## `[node "name"]` fields

| Field | Required | Description |
| --- | --- | --- |
| `address` | ✅ | Node mesh IP (CIDR, RFC1918 or ULA). |
| `endpoint` | ✅ | `host:port` or `[ipv6]:port`. |
| `allowed_ips` | ✅ | AllowedIPs for this peer (typically `/32`). |
| `public_key` | ✅* | Required unless `--gen-keys` or `private_key` is provided. |
| `private_key` | ❌ | Inline private key (optional). |
| `private_key_path` | ❌ | Path to private key (optional). |
| `persistent_keepalive` | ❌ | Keepalive seconds (e.g., 25). |
| `endpoint_alt` | ❌ | Optional failover endpoint. |
| `ssh_host` | ❌ | SSH host override for `apply-remote`. |
| `ssh_user` | ❌ | SSH user override for `apply-remote`. |
| `ssh_port` | ❌ | SSH port override for `apply-remote`. |
| `forwarding` | ❌ | `true/false` to enable IPv4 forwarding. |
| `nat_iface` | ❌ | Interface for NAT/forwarding rules. |
| `post_up` | ❌ | Extra PostUp commands (appended). |
| `post_down` | ❌ | Extra PostDown commands (appended). |
| `exit_out_iface` | ❌ | Required for exit nodes (NAT interface). |
| `enable_nat` | ❌ | Required for exit nodes (set `true`). |

> **Note:** The `allowed_ips` field stays `/32` per peer in both full-mesh and star topologies. Exit routing is handled by policy routing and the exit selector.

## Example: full mesh (default)
```ini
[mesh]
interface = wg0
port = 51820
dns = 1.1.1.1
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

## Example: star topology
```ini
[mesh]
interface = wg0
port = 51820
dns = 1.1.1.1
mesh_cidr = 10.40.0.0/24
topology = star
hubs = alpha
hub_selection = static

[node "alpha"]
address = 10.40.0.1/32
endpoint = alpha.example.com:51820
allowed_ips = 10.40.0.1/32
public_key = <ALPHA_PUBLIC_KEY>
private_key = <ALPHA_PRIVATE_KEY>
forwarding = true

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
