# Troubleshooting

## WireGuard status

```bash
wg show
wg show wg0
```

## Policy routing

```bash
ip rule show
ip route show table main
ip route show table 101
```

## Connectivity checks

```bash
ping -c 3 10.40.0.1
ping -c 3 1.1.1.1
```

## Packet capture

```bash
tcpdump -ni wg0
```

## Firewall/NAT rules

```bash
iptables -S
iptables -t nat -S
iptables -t mangle -S
```

## systemd services

```bash
systemctl status wg-quick@wg0.service
systemctl status wg-failover.timer
systemctl status wg-exit-selector.timer
```
