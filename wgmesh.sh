#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG="${ROOT_DIR}/mesh.conf"
DEFAULT_OUT_DIR="${ROOT_DIR}/out"

usage() {
  cat <<'USAGE'
Usage: wgmesh.sh <command> [options]

Commands:
  validate                 Validate mesh.conf inventory and required fields.
  gen                      Generate WireGuard configs for all nodes.
  gen-keys                 Generate missing keypairs and write them to mesh.conf.
  install-failover         Install wg-failover script and systemd units.
  apply                    Generate and install config for a single node.
  apply-remote             Apply config to remote node(s) over SSH.

Options (common):
  -c, --config <path>      Path to mesh.conf (default: ./mesh.conf)
  -o, --out <dir>          Output directory for generated configs (default: ./out)
  --gen-keys               Generate missing keypairs locally (requires wg).

Options (apply):
  -n, --node <name>        Node name to install on this host (or set local_node in [mesh]).
  --interface <ifname>     Override interface name (default from mesh.conf).
  --dry-run                Print target paths without writing.

Options (apply-remote):
  -n, --node <name>        Node name to install on remote host.
  --all                    Apply to all nodes in inventory.
  --interface <ifname>     Override interface name (default from mesh.conf).
  --ssh-tty                Allocate a TTY for SSH (useful for sudo prompts).
  --dry-run                Print target paths without writing.

Examples:
  ./wgmesh.sh validate
  ./wgmesh.sh gen -o ./out
  ./wgmesh.sh gen-keys
  sudo ./wgmesh.sh apply --node alpha
  sudo ./wgmesh.sh install-failover
  ./wgmesh.sh apply-remote --all
USAGE
}

trim() {
  local s="$1"
  s="${s#${s%%[![:space:]]*}}"
  s="${s%${s##*[![:space:]]}}"
  printf '%s' "$s"
}

is_truthy() {
  local value
  value="$(trim "${1:-}")"
  shopt -s nocasematch
  if [[ "$value" =~ ^(true|yes|1)$ ]]; then
    shopt -u nocasematch
    return 0
  fi
  shopt -u nocasematch
  return 1
}

is_placeholder() {
  local value="$1"
  [[ -n "$value" && "$value" =~ ^\<.*\>$ ]]
}

parse_mesh_conf() {
  local file="$1"
  awk '
    function trim(s){gsub(/^[ \t]+|[ \t]+$/, "", s); return s}
    function strip_comment(s){
      sub(/[ \t]+#.*$/, "", s)
      return s
    }
    BEGIN{section=""; name=""}
    /^[ \t]*#/ {next}
    /^[ \t]*$/ {next}
    /^\[/{
      section=$0
      gsub(/^\[|\]$/, "", section)
      name=""
      if (tolower(section) ~ /^node[[:space:]]+/) {
        name=section
        sub(/^node[[:space:]]+/, "", name)
        gsub(/^"|"$/, "", name)
        section="node"
      }
      section=tolower(section)
      next
    }
    {
      line=strip_comment($0)
      split(line, kv, "=")
      key=trim(kv[1])
      val=substr(line, index(line, "=") + 1)
      val=trim(val)
      if (section == "node") {
        printf("node|%s|%s|%s\n", name, tolower(key), val)
      } else if (section != "") {
        printf("%s||%s|%s\n", section, tolower(key), val)
      }
    }
  ' "$file"
}

resolve_private_key() {
  local node="$1"
  local out_dir="$2"
  local gen_keys="$3"
  local private_key="${NODE_FIELDS[$node.private_key]:-}"
  local private_key_path="${NODE_FIELDS[$node.private_key_path]:-}"

  if is_placeholder "$private_key"; then
    private_key=""
  fi

  if [[ -n "$private_key" ]] && ! is_placeholder "$private_key"; then
    echo "$private_key"
    return
  fi

  if [[ -n "$private_key_path" && -f "$private_key_path" ]]; then
    cat "$private_key_path"
    return
  fi

  if [[ "$gen_keys" == "true" ]]; then
    if ! command -v wg >/dev/null 2>&1; then
      echo "wg is required to generate keys but was not found in PATH." >&2
      exit 1
    fi
    if [[ -z "$private_key_path" ]]; then
      private_key_path="$out_dir/keys/${node}.key"
      NODE_FIELDS["$node.private_key_path"]="$private_key_path"
    fi
    mkdir -p "$(dirname "$private_key_path")"
    umask 077
    wg genkey > "$private_key_path"
    umask 022
    private_key="$(cat "$private_key_path")"
    NODE_FIELDS["$node.private_key"]="$private_key"
    echo "$private_key"
    return
  fi

  echo "<PLACE_PRIVATE_KEY_HERE>"
}

resolve_ssh_target() {
  local node="$1"
  local host="${NODE_FIELDS[$node.ssh_host]:-}"
  local user="${NODE_FIELDS[$node.ssh_user]:-}"

  if [[ -z "$host" ]]; then
    host="$node"
  fi

  if [[ -n "$user" ]]; then
    echo "${user}@${host}"
  else
    echo "$host"
  fi
}

resolve_public_key() {
  local node="$1"
  local out_dir="$2"
  local gen_keys="$3"
  local public_key="${NODE_FIELDS[$node.public_key]:-}"

  if is_placeholder "$public_key"; then
    public_key=""
  fi

  if [[ -n "$public_key" ]] && ! is_placeholder "$public_key"; then
    echo "$public_key"
    return
  fi

  local private_key="${NODE_FIELDS[$node.private_key]:-}"
  local private_key_path="${NODE_FIELDS[$node.private_key_path]:-}"
  if is_placeholder "$private_key"; then
    private_key=""
  fi
  if [[ -z "$private_key" && -n "$private_key_path" && -f "$private_key_path" ]]; then
    private_key="$(cat "$private_key_path")"
  fi

  if [[ -n "$private_key" ]]; then
    if ! command -v wg >/dev/null 2>&1; then
      echo "wg is required to derive public keys but was not found in PATH." >&2
      exit 1
    fi
    public_key="$(printf '%s' "$private_key" | wg pubkey)"
    NODE_FIELDS["$node.public_key"]="$public_key"
    echo "$public_key"
    return
  fi

  if [[ "$gen_keys" == "true" ]]; then
    if ! command -v wg >/dev/null 2>&1; then
      echo "wg is required to generate public keys but was not found in PATH." >&2
      exit 1
    fi
    local private_key
    private_key="$(resolve_private_key "$node" "$out_dir" "$gen_keys")"
    if [[ "$private_key" == "<PLACE_PRIVATE_KEY_HERE>" ]]; then
      echo "" >&2
      return
    fi
    public_key="$(printf '%s' "$private_key" | wg pubkey)"
    NODE_FIELDS["$node.public_key"]="$public_key"
    echo "$public_key"
    return
  fi

  echo ""
}

build_post_commands() {
  local node="$1"
  local phase="$2"
  local forwarding="${NODE_FIELDS[$node.forwarding]:-}"
  local nat_iface="${NODE_FIELDS[$node.nat_iface]:-}"
  local extra_up="${NODE_FIELDS[$node.post_up]:-}"
  local extra_down="${NODE_FIELDS[$node.post_down]:-}"
  local cmds=()

  if [[ "$phase" == "up" ]]; then
    if is_truthy "$forwarding"; then
      cmds+=("sysctl -w net.ipv4.ip_forward=1")
    fi
    if [[ -n "$nat_iface" ]]; then
      cmds+=("iptables -A FORWARD -i %i -o $nat_iface -j ACCEPT")
      cmds+=("iptables -A FORWARD -i $nat_iface -o %i -m state --state RELATED,ESTABLISHED -j ACCEPT")
      cmds+=("iptables -t nat -A POSTROUTING -o $nat_iface -j MASQUERADE")
    fi
    if [[ -n "$extra_up" ]]; then
      cmds+=("$extra_up")
    fi
  else
    if [[ -n "$nat_iface" ]]; then
      cmds+=("iptables -D FORWARD -i %i -o $nat_iface -j ACCEPT")
      cmds+=("iptables -D FORWARD -i $nat_iface -o %i -m state --state RELATED,ESTABLISHED -j ACCEPT")
      cmds+=("iptables -t nat -D POSTROUTING -o $nat_iface -j MASQUERADE")
    fi
    if [[ -n "$extra_down" ]]; then
      cmds+=("$extra_down")
    fi
  fi

  if [[ ${#cmds[@]} -eq 0 ]]; then
    echo ""
    return
  fi

  local IFS='; '
  echo "${cmds[*]}"
}

validate_endpoint() {
  local endpoint="$1"
  if [[ "$endpoint" =~ ^\[[0-9a-fA-F:]+\]:[0-9]+$ ]]; then
    return 0
  fi
  if [[ "$endpoint" =~ ^[^:]+:[0-9]+$ ]]; then
    return 0
  fi
  return 1
}

validate_cidr() {
  local cidr="$1"
  if [[ "$cidr" =~ ^[0-9a-fA-F:.]+/[0-9]+$ ]]; then
    return 0
  fi
  return 1
}

load_config() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "Config not found: $file" >&2
    exit 1
  fi

  declare -gA MESH=()
  declare -gA NODE_FIELDS=()
  declare -gA NODE_NAMES=()

  while IFS='|' read -r section name key value; do
    if [[ "$section" == "node" ]]; then
      NODE_NAMES["$name"]=1
      NODE_FIELDS["$name.$key"]="$value"
    else
      MESH["$key"]="$value"
    fi
  done < <(parse_mesh_conf "$file")
}

print_inventory() {
  echo "Inventory:"
  local node_name
  for node_name in "${!NODE_NAMES[@]}"; do
    local address="${NODE_FIELDS[$node_name.address]:-}"
    local endpoint="${NODE_FIELDS[$node_name.endpoint]:-}"
    local endpoint_alt="${NODE_FIELDS[$node_name.endpoint_alt]:-}"
    local allowed_ips="${NODE_FIELDS[$node_name.allowed_ips]:-}"
    printf '  - %s\n' "$node_name"
    printf '    address: %s\n' "$address"
    printf '    endpoint: %s\n' "$endpoint"
    if [[ -n "$endpoint_alt" ]]; then
      printf '    endpoint_alt: %s\n' "$endpoint_alt"
    fi
    printf '    allowed_ips: %s\n' "$allowed_ips"
  done
}

validate_config() {
  local file="$1"
  local gen_keys="$2"
  load_config "$file"

  local errors=0

  if [[ -z "${MESH[interface]:-}" ]]; then
    echo "Missing mesh interface in [mesh] section" >&2
    errors=$((errors + 1))
  fi

  if [[ ${#NODE_NAMES[@]} -eq 0 ]]; then
    echo "No nodes defined in mesh inventory" >&2
    errors=$((errors + 1))
  fi

  declare -A seen_addresses=()
  declare -A seen_pubkeys=()

  local node_name
  for node_name in "${!NODE_NAMES[@]}"; do
    local address="${NODE_FIELDS[$node_name.address]:-}"
    local public_key="${NODE_FIELDS[$node_name.public_key]:-}"
    local endpoint="${NODE_FIELDS[$node_name.endpoint]:-}"
    local endpoint_alt="${NODE_FIELDS[$node_name.endpoint_alt]:-}"
    local allowed_ips="${NODE_FIELDS[$node_name.allowed_ips]:-}"

    if [[ -z "$address" || -z "$endpoint" || -z "$allowed_ips" ]]; then
      echo "Node $node_name missing required fields (address, endpoint, allowed_ips)" >&2
      errors=$((errors + 1))
    fi

    if [[ -n "$public_key" ]] && is_placeholder "$public_key"; then
      public_key=""
    fi
    if [[ -z "$public_key" && "$gen_keys" != "true" ]]; then
      local private_key="${NODE_FIELDS[$node_name.private_key]:-}"
      local private_key_path="${NODE_FIELDS[$node_name.private_key_path]:-}"
      if [[ -z "$private_key" && -n "$private_key_path" && -f "$private_key_path" ]]; then
        private_key="present"
      fi
      if [[ -z "$private_key" ]]; then
        echo "Node $node_name missing required field: public_key" >&2
        errors=$((errors + 1))
      elif ! command -v wg >/dev/null 2>&1; then
        echo "Node $node_name needs wg to derive public_key from private_key." >&2
        errors=$((errors + 1))
      fi
    fi

    if [[ -n "$address" ]] && ! validate_cidr "$address"; then
      echo "Node $node_name address is not CIDR: $address" >&2
      errors=$((errors + 1))
    fi

    if [[ -n "$allowed_ips" ]]; then
      IFS=',' read -ra ips <<< "$allowed_ips"
      for ip in "${ips[@]}"; do
        ip="$(trim "$ip")"
        if [[ -n "$ip" ]] && ! validate_cidr "$ip"; then
          echo "Node $node_name allowed_ips contains non-CIDR entry: $ip" >&2
          errors=$((errors + 1))
        fi
      done
    fi

    if [[ -n "$endpoint" ]] && ! validate_endpoint "$endpoint"; then
      echo "Node $node_name endpoint is invalid: $endpoint" >&2
      errors=$((errors + 1))
    fi

    if [[ -n "$endpoint_alt" ]] && ! validate_endpoint "$endpoint_alt"; then
      echo "Node $node_name endpoint_alt is invalid: $endpoint_alt" >&2
      errors=$((errors + 1))
    fi

    if [[ -n "$address" ]]; then
      if [[ -n "${seen_addresses[$address]:-}" ]]; then
        echo "Duplicate address: $address" >&2
        errors=$((errors + 1))
      else
        seen_addresses[$address]=1
      fi
    fi

    if [[ -n "$public_key" ]]; then
      if [[ -n "${seen_pubkeys[$public_key]:-}" ]]; then
        echo "Duplicate public_key for node $node_name" >&2
        errors=$((errors + 1))
      else
        seen_pubkeys[$public_key]=1
      fi
    fi
  done

  if [[ $errors -ne 0 ]]; then
    echo "Validation failed with $errors error(s)." >&2
    exit 1
  fi

  print_inventory
  echo "Validation succeeded."
}

gen_configs() {
  local file="$1"
  local out_dir="$2"
  local gen_keys="$3"

  if [[ "$gen_keys" == "true" ]]; then
    generate_keys_for_inventory "$file" "$out_dir"
  fi

  validate_config "$file" "$gen_keys"

  mkdir -p "$out_dir"

  local node_name
  for node_name in "${!NODE_NAMES[@]}"; do
    local iface="${MESH[interface]}"
    local address="${NODE_FIELDS[$node_name.address]:-}"
    local private_key_value
    private_key_value="$(resolve_private_key "$node_name" "$out_dir" "$gen_keys")"
    local private_key_path="${NODE_FIELDS[$node_name.private_key_path]:-/etc/wireguard/${iface}.key}"
    local listen_port="${MESH[port]:-51820}"
    local dns="${MESH[dns]:-}"
    local post_up
    local post_down
    post_up="$(build_post_commands "$node_name" "up")"
    post_down="$(build_post_commands "$node_name" "down")"

    resolve_public_key "$node_name" "$out_dir" "$gen_keys" >/dev/null

    local out_file="$out_dir/${node_name}.conf"
    {
      echo "[Interface]"
      echo "Address = $address"
      echo "PrivateKey = $private_key_value"
      echo "# PrivateKey file: $private_key_path"
      echo "ListenPort = $listen_port"
      if [[ -n "$dns" ]]; then
        echo "DNS = $dns"
      fi
      if [[ -n "$post_up" ]]; then
        echo "PostUp = $post_up"
      fi
      if [[ -n "$post_down" ]]; then
        echo "PostDown = $post_down"
      fi
      echo ""

      for peer in "${!NODE_NAMES[@]}"; do
        if [[ "$peer" == "$node_name" ]]; then
          continue
        fi
        local peer_key
        peer_key="$(resolve_public_key "$peer" "$out_dir" "$gen_keys")"
        local peer_allowed="${NODE_FIELDS[$peer.allowed_ips]:-}"
        local peer_endpoint="${NODE_FIELDS[$peer.endpoint]:-}"
        local keepalive="${NODE_FIELDS[$peer.persistent_keepalive]:-}"

        echo "[Peer]"
        echo "PublicKey = $peer_key"
        echo "AllowedIPs = $peer_allowed"
        echo "Endpoint = $peer_endpoint"
        if [[ -n "$keepalive" ]]; then
          echo "PersistentKeepalive = $keepalive"
        fi
        echo ""
      done
    } > "$out_file"
  done

  local failover_file="$out_dir/wg-failover.conf"
  {
    echo "# Generated failover configuration"
    echo "INTERFACE=${MESH[interface]}"
    echo "PEERS=("
    local node_name
    for node_name in "${!NODE_NAMES[@]}"; do
      local pubkey="${NODE_FIELDS[$node_name.public_key]:-}"
      local primary="${NODE_FIELDS[$node_name.endpoint]:-}"
      local secondary="${NODE_FIELDS[$node_name.endpoint_alt]:-}"
      echo "  \"$node_name|$pubkey|$primary|$secondary\""
    done
    echo ")"
  } > "$failover_file"

  echo "Generated configs in $out_dir"
}

generate_keys_for_inventory() {
  local file="$1"
  local out_dir="$2"

  load_config "$file"

  if ! command -v wg >/dev/null 2>&1; then
    echo "wg is required to generate keys but was not found in PATH." >&2
    exit 1
  fi

  local keyfile
  keyfile="$(mktemp)"

  local node_name
  for node_name in "${!NODE_NAMES[@]}"; do
    local private_key
    local public_key
    private_key="$(resolve_private_key "$node_name" "$out_dir" "true")"
    public_key="$(resolve_public_key "$node_name" "$out_dir" "true")"

    if [[ "$private_key" == "<PLACE_PRIVATE_KEY_HERE>" || -z "$public_key" ]]; then
      echo "Failed to generate keys for $node_name." >&2
      rm -f "$keyfile"
      exit 1
    fi

    printf '%s\t%s\t%s\n' "$node_name" "$private_key" "$public_key" >> "$keyfile"
  done

  local python_bin="python"
  if ! command -v "$python_bin" >/dev/null 2>&1; then
    python_bin="python3"
  fi
  if ! command -v "$python_bin" >/dev/null 2>&1; then
    echo "python (or python3) is required to update the config but was not found in PATH." >&2
    rm -f "$keyfile"
    exit 1
  fi

  "$python_bin" - "$file" "$keyfile" <<'PY'
import os
import re
import sys

config_path = sys.argv[1]
key_path = sys.argv[2]

keys = {}
with open(key_path, "r", encoding="utf-8") as handle:
    for line in handle:
        node, private_key, public_key = line.rstrip("\n").split("\t")
        keys[node] = {
            "private_key": private_key,
            "public_key": public_key,
        }

section_re = re.compile(r'^\s*\[\s*node\s+"?([^"]+)"?\s*\]\s*$', re.IGNORECASE)
key_re = re.compile(r'^\s*(private_key|public_key)\s*=', re.IGNORECASE)
blank_re = re.compile(r'^\s*$')
comment_re = re.compile(r'^\s*#')

lines = []
with open(config_path, "r", encoding="utf-8") as handle:
    lines = handle.read().splitlines()

output = []
current_node = None
seen_private = False
seen_public = False
pending = []

def flush_pending():
    if pending:
        output.extend(pending)
        pending.clear()

def flush_missing():
    if current_node and current_node in keys:
        if not seen_private:
            output.append(f"private_key = {keys[current_node]['private_key']}")
        if not seen_public:
            output.append(f"public_key = {keys[current_node]['public_key']}")
    flush_pending()

for line in lines:
    section_match = section_re.match(line)
    if section_match:
        flush_missing()
        current_node = section_match.group(1)
        seen_private = False
        seen_public = False
        output.append(line)
        continue

    if current_node and (blank_re.match(line) or comment_re.match(line)):
        pending.append(line)
        continue

    flush_pending()

    if current_node and key_re.match(line):
        key_name = key_re.match(line).group(1).lower()
        if key_name == "private_key":
            output.append(f"private_key = {keys[current_node]['private_key']}")
            seen_private = True
        elif key_name == "public_key":
            output.append(f"public_key = {keys[current_node]['public_key']}")
            seen_public = True
        continue

    output.append(line)

flush_missing()

tmp_path = config_path + ".tmp"
with open(tmp_path, "w", encoding="utf-8") as handle:
    handle.write("\n".join(output) + "\n")

os.replace(tmp_path, config_path)
PY

  rm -f "$keyfile"
  echo "Updated keys in $file"
}

install_failover() {
  local script_src="$ROOT_DIR/usr/local/bin/wg-failover"
  local service_src="$ROOT_DIR/wg-failover.service"
  local timer_src="$ROOT_DIR/wg-failover.timer"

  if [[ ! -f "$script_src" ]]; then
    echo "Template not found: $script_src" >&2
    exit 1
  fi

  install -m 0755 "$script_src" /usr/local/bin/wg-failover
  install -m 0644 "$service_src" /etc/systemd/system/wg-failover.service
  install -m 0644 "$timer_src" /etc/systemd/system/wg-failover.timer

  systemctl daemon-reload
  echo "Installed wg-failover templates. Enable with: systemctl enable --now wg-failover.timer"
}

apply_config() {
  local file="$1"
  local node="$2"
  local out_dir="$3"
  local override_iface="$4"
  local dry_run="$5"
  local gen_keys="$6"

  if [[ -z "$node" ]]; then
    load_config "$file"
    node="${MESH[local_node]:-}"
    if [[ -z "$node" ]]; then
      echo "--node is required for apply (or set local_node in [mesh])." >&2
      exit 1
    fi
  fi

  gen_configs "$file" "$out_dir" "$gen_keys"
  load_config "$file"

  local iface="${MESH[interface]}"
  if [[ -n "$override_iface" ]]; then
    iface="$override_iface"
  fi

  local source_conf="$out_dir/${node}.conf"
  local target_conf="/etc/wireguard/${iface}.conf"
  local failover_conf="$out_dir/wg-failover.conf"
  local target_failover="/etc/wireguard/wg-failover.conf"

  if [[ "$dry_run" == "true" ]]; then
    echo "Would install $source_conf to $target_conf"
    echo "Would install $failover_conf to $target_failover"
    return 0
  fi

  if [[ ! -f "$source_conf" ]]; then
    echo "Config for node $node not found: $source_conf" >&2
    exit 1
  fi

  install -m 0600 "$source_conf" "$target_conf"
  install -m 0644 "$failover_conf" "$target_failover"

  systemctl enable --now "wg-quick@${iface}.service"
  systemctl restart "wg-quick@${iface}.service"

  echo "Applied config for $node to $target_conf"
}

apply_remote() {
  local file="$1"
  local node="$2"
  local out_dir="$3"
  local override_iface="$4"
  local dry_run="$5"
  local all_nodes="$6"
  local gen_keys="$7"
  local ssh_tty="$8"
  local script_src="$ROOT_DIR/usr/local/bin/wg-failover"
  local service_src="$ROOT_DIR/wg-failover.service"
  local timer_src="$ROOT_DIR/wg-failover.timer"

  if [[ "$all_nodes" != "true" && -z "$node" ]]; then
    echo "--node or --all is required for apply-remote" >&2
    exit 1
  fi

  gen_configs "$file" "$out_dir" "$gen_keys"
  load_config "$file"

  if [[ ! -f "$script_src" ]]; then
    echo "Template not found: $script_src" >&2
    exit 1
  fi

  local iface="${MESH[interface]}"
  if [[ -n "$override_iface" ]]; then
    iface="$override_iface"
  fi

  local nodes_to_apply=()
  if [[ "$all_nodes" == "true" ]]; then
    for node_name in "${!NODE_NAMES[@]}"; do
      nodes_to_apply+=("$node_name")
    done
  else
    nodes_to_apply+=("$node")
  fi

  local failover_conf="$out_dir/wg-failover.conf"

  for node_name in "${nodes_to_apply[@]}"; do
    local source_conf="$out_dir/${node_name}.conf"
    local ssh_port="${NODE_FIELDS[$node_name.ssh_port]:-}"
    local ssh_target
    ssh_target="$(resolve_ssh_target "$node_name")"

    local ssh_cmd=(ssh)
    local scp_cmd=(scp)
    if [[ -n "$ssh_port" ]]; then
      ssh_cmd+=(-p "$ssh_port")
      scp_cmd+=(-P "$ssh_port")
    fi
    if [[ "$ssh_tty" == "true" ]]; then
      ssh_cmd+=(-t)
    fi

    local remote_dir="/tmp/wgmesh-${node_name}"
    local remote_conf="${remote_dir}/${iface}.conf"
    local remote_failover="${remote_dir}/wg-failover.conf"
    local remote_script="${remote_dir}/wg-failover"
    local remote_service="${remote_dir}/wg-failover.service"
    local remote_timer="${remote_dir}/wg-failover.timer"
    local target_conf="/etc/wireguard/${iface}.conf"
    local target_failover="/etc/wireguard/wg-failover.conf"
    local target_script="/usr/local/bin/wg-failover"
    local target_service="/etc/systemd/system/wg-failover.service"
    local target_timer="/etc/systemd/system/wg-failover.timer"

    if [[ "$dry_run" == "true" ]]; then
      echo "Would copy $source_conf to $ssh_target:$remote_conf"
      echo "Would copy $failover_conf to $ssh_target:$remote_failover"
      echo "Would copy $script_src to $ssh_target:$remote_script"
      echo "Would copy $service_src to $ssh_target:$remote_service"
      echo "Would copy $timer_src to $ssh_target:$remote_timer"
      echo "Would install to $target_conf, $target_failover, $target_script, $target_service, and $target_timer on $ssh_target"
      continue
    fi

    if [[ ! -f "$source_conf" ]]; then
      echo "Config for node $node_name not found: $source_conf" >&2
      exit 1
    fi

    "${ssh_cmd[@]}" "$ssh_target" "mkdir -p '$remote_dir'"
    "${scp_cmd[@]}" "$source_conf" "$ssh_target:$remote_conf"
    "${scp_cmd[@]}" "$failover_conf" "$ssh_target:$remote_failover"
    "${scp_cmd[@]}" "$script_src" "$ssh_target:$remote_script"
    "${scp_cmd[@]}" "$service_src" "$ssh_target:$remote_service"
    "${scp_cmd[@]}" "$timer_src" "$ssh_target:$remote_timer"
    "${ssh_cmd[@]}" "$ssh_target" \
      "sudo install -m 0600 '$remote_conf' '$target_conf' && \
       sudo install -m 0644 '$remote_failover' '$target_failover' && \
       sudo install -m 0755 '$remote_script' '$target_script' && \
       sudo install -m 0644 '$remote_service' '$target_service' && \
       sudo install -m 0644 '$remote_timer' '$target_timer' && \
       sudo systemctl daemon-reload && \
       sudo systemctl enable --now 'wg-quick@${iface}.service' && \
       sudo systemctl restart 'wg-quick@${iface}.service' && \
       rm -f '$remote_conf' '$remote_failover' '$remote_script' '$remote_service' '$remote_timer' && \
       rmdir '$remote_dir' 2>/dev/null || true"

    echo "Applied config for $node_name to $ssh_target:$target_conf"
  done
}

main() {
  if [[ $# -lt 1 ]]; then
    usage
    exit 1
  fi

  local cmd="$1"
  shift

  local config="$DEFAULT_CONFIG"
  local out_dir="$DEFAULT_OUT_DIR"
  local node=""
  local override_iface=""
  local dry_run="false"
  local all_nodes="false"
  local gen_keys="false"
  local ssh_tty="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--config)
        config="$2"
        shift 2
        ;;
      -o|--out)
        out_dir="$2"
        shift 2
        ;;
      -n|--node)
        node="$2"
        shift 2
        ;;
      --interface)
        override_iface="$2"
        shift 2
        ;;
      --dry-run)
        dry_run="true"
        shift
        ;;
      --all)
        all_nodes="true"
        shift
        ;;
      --ssh-tty)
        ssh_tty="true"
        shift
        ;;
      --gen-keys)
        gen_keys="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage
        exit 1
        ;;
    esac
  done

  case "$cmd" in
    validate)
      validate_config "$config" "$gen_keys"
      ;;
    gen)
      gen_configs "$config" "$out_dir" "$gen_keys"
      ;;
    gen-keys)
      generate_keys_for_inventory "$config" "$out_dir"
      ;;
    install-failover)
      install_failover
      ;;
    apply)
      apply_config "$config" "$node" "$out_dir" "$override_iface" "$dry_run" "$gen_keys"
      ;;
    apply-remote)
      apply_remote "$config" "$node" "$out_dir" "$override_iface" "$dry_run" "$all_nodes" "$gen_keys" "$ssh_tty"
      ;;
    *)
      echo "Unknown command: $cmd" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
