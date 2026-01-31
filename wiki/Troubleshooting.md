# Troubleshooting

## WireGuard

```bash
wg show
wg show wg0
wg show wg0 latest-handshakes
```

## Routing / policy rules

```bash
ip rule show
ip route show table 101
ip route show
```

## Firewall / NAT

```bash
iptables -S
iptables -t nat -S
iptables -t mangle -S
nft list ruleset
```

## Packet capture

```bash
tcpdump -ni wg0
tcpdump -ni eth0 host 1.1.1.1
```

## Common issues

- **No handshakes**: verify endpoints, keys, and UDP reachability.
- **Exit routing fails**: check `Table = off`, `ip rule`, and `TABLE_EXIT` routes.
- **Hub forwarding issues**: confirm `net.ipv4.ip_forward=1` and wg->wg rules.
