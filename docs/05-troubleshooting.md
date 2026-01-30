# Troubleshooting

## WireGuard status

```bash
sudo wg show
sudo wg show wg0
```

## Routing and policy rules

```bash
ip rule show
ip route show table main
ip route show table 101
```

## Interface and sysctl

```bash
ip -br addr show wg0
sysctl net.ipv4.ip_forward
```

## Packet capture

```bash
sudo tcpdump -ni wg0
sudo tcpdump -ni eth0 host 1.1.1.1
```

## iptables / nftables

```bash
sudo iptables -S
sudo iptables -t nat -S
sudo iptables -t mangle -S
```

For nft-based systems:

```bash
sudo nft list ruleset
```
