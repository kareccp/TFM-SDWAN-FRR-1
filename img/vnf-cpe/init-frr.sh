#!/bin/sh

set -xe

exec > /tmp/init-frr.log 2>&1

echo "Iniciando CPE con FRR..."

# Eliminar default route de gestión
ip route del default via 172.20.20.1 dev eth0 2>/dev/null || true

# Activar interfaces importantes
ip link set brint up
ip link set net1 up

# Activar forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# NAT con script original
/vnx_config_nat brint net1 || echo "vnx_config_nat falló"

# fallback NAT
iptables -t nat -A POSTROUTING -o net1 -j MASQUERADE

# Iniciar FRR
echo "Arrancando FRR..."

if [ -x /usr/lib/frr/frrinit.sh ]; then
  rm -f /var/run/frr/watchfrr.pid
  /usr/lib/frr/frrinit.sh start
fi

echo "FRR iniciado"

tail -f /dev/null

