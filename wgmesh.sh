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
  install-failover         Install wg-failover script and systemd units.
  apply                    Generate and install config for a single node.

Options (common):
  -c, --config <path>      Path to mesh.conf (default: ./mesh.conf)
  -o, --out <dir>          Output directory for generated configs (default: ./out)

Options (apply):
  -n, --node <name>        Node name to install on this host (required).
  --interface <ifname>     Override interface name (default from mesh.conf).
  --dry-run                Print target paths without writing.

Examples:
  ./wgmesh.sh validate
  ./wgmesh.sh gen -o ./out
  sudo ./wgmesh.sh apply --node alpha
  sudo ./wgmesh.sh install-failover
USAGE
}

trim() {
  local s="$1"
  s="${s#${s%%[![:space:]]*}}"
  s="${s%${s##*[![:space:]]}}"
  printf '%s' "$s"
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
  local private_key="${NODE_FIELDS[$node.private_key]:-}"
  local private_key_path="${NODE_FIELDS[$node.private_key_path]:-}"

  if [[ -n "$private_key" ]]; then
    echo "$private_key"
    return
  fi

  if [[ -n "$private_key_path" && -f "$private_key_path" ]]; then
    cat "$private_key_path"
    return
  fi

  echo "<PLACE_PRIVATE_KEY_HERE>"
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
  for node in "${!NODE_NAMES[@]}"; do
    local address="${NODE_FIELDS[$node.address]:-}"
    local endpoint="${NODE_FIELDS[$node.endpoint]:-}"
    local endpoint_alt="${NODE_FIELDS[$node.endpoint_alt]:-}"
    local allowed_ips="${NODE_FIELDS[$node.allowed_ips]:-}"
    printf '  - %s\n' "$node"
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

  for node in "${!NODE_NAMES[@]}"; do
    local address="${NODE_FIELDS[$node.address]:-}"
    local public_key="${NODE_FIELDS[$node.public_key]:-}"
    local endpoint="${NODE_FIELDS[$node.endpoint]:-}"
    local endpoint_alt="${NODE_FIELDS[$node.endpoint_alt]:-}"
    local allowed_ips="${NODE_FIELDS[$node.allowed_ips]:-}"

    if [[ -z "$address" || -z "$public_key" || -z "$endpoint" || -z "$allowed_ips" ]]; then
      echo "Node $node missing required fields (address, public_key, endpoint, allowed_ips)" >&2
      errors=$((errors + 1))
    fi

    if [[ -n "$address" ]] && ! validate_cidr "$address"; then
      echo "Node $node address is not CIDR: $address" >&2
      errors=$((errors + 1))
    fi

    if [[ -n "$allowed_ips" ]]; then
      IFS=',' read -ra ips <<< "$allowed_ips"
      for ip in "${ips[@]}"; do
        ip="$(trim "$ip")"
        if [[ -n "$ip" ]] && ! validate_cidr "$ip"; then
          echo "Node $node allowed_ips contains non-CIDR entry: $ip" >&2
          errors=$((errors + 1))
        fi
      done
    fi

    if [[ -n "$endpoint" ]] && ! validate_endpoint "$endpoint"; then
      echo "Node $node endpoint is invalid: $endpoint" >&2
      errors=$((errors + 1))
    fi

    if [[ -n "$endpoint_alt" ]] && ! validate_endpoint "$endpoint_alt"; then
      echo "Node $node endpoint_alt is invalid: $endpoint_alt" >&2
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
        echo "Duplicate public_key for node $node" >&2
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

  validate_config "$file"

  mkdir -p "$out_dir"

  for node in "${!NODE_NAMES[@]}"; do
    local iface="${MESH[interface]}"
    local address="${NODE_FIELDS[$node.address]:-}"
    local private_key_path="${NODE_FIELDS[$node.private_key_path]:-/etc/wireguard/${iface}.key}"
    local private_key_value
    private_key_value="$(resolve_private_key "$node")"
    local listen_port="${MESH[port]:-51820}"
    local dns="${MESH[dns]:-}"

    local out_file="$out_dir/${node}.conf"
    {
      echo "[Interface]"
      echo "Address = $address"
      echo "PrivateKey = $private_key_value"
      echo "# PrivateKey file: $private_key_path"
      echo "ListenPort = $listen_port"
      if [[ -n "$dns" ]]; then
        echo "DNS = $dns"
      fi
      echo ""

      for peer in "${!NODE_NAMES[@]}"; do
        if [[ "$peer" == "$node" ]]; then
          continue
        fi
        local peer_key="${NODE_FIELDS[$peer.public_key]:-}"
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
    for node in "${!NODE_NAMES[@]}"; do
      local pubkey="${NODE_FIELDS[$node.public_key]:-}"
      local primary="${NODE_FIELDS[$node.endpoint]:-}"
      local secondary="${NODE_FIELDS[$node.endpoint_alt]:-}"
      echo "  \"$node|$pubkey|$primary|$secondary\""
    done
    echo ")"
  } > "$failover_file"

  echo "Generated configs in $out_dir"
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

  if [[ -z "$node" ]]; then
    echo "--node is required for apply" >&2
    exit 1
  fi

  gen_configs "$file" "$out_dir"
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
      validate_config "$config"
      ;;
    gen)
      gen_configs "$config" "$out_dir"
      ;;
    install-failover)
      install_failover
      ;;
    apply)
      apply_config "$config" "$node" "$out_dir" "$override_iface" "$dry_run"
      ;;
    *)
      echo "Unknown command: $cmd" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
