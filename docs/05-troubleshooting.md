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

## Check generated routes and marks
```bash
iptables -t mangle -L OUTPUT -n -v
iptables -t nat -L POSTROUTING -n -v
```

## Interface state
```bash
ip link show wg0
ip addr show wg0
```

## Connectivity testing
```bash
ping -c3 10.40.0.1
ping -c3 -I wg0 10.40.0.2
```

## Packet capture
```bash
tcpdump -i wg0
```

## Exit selector status
```bash
wg-exit-selector status
```

## systemd
```bash
systemctl status wg-quick@wg0.service
systemctl status wg-failover.timer
systemctl status wg-exit-selector.timer
```
