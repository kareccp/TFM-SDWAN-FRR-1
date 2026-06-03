#!/bin/bash

set -xe

echo "Iniciando CPE con FRR..."

# Log por si necesitas debug
exec > /tmp/init-frr.log 2>&1

# Activar forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Esperar interfaces
sleep 5

echo "Interfaces detectadas:"
ip a

# Interfaces reales (IMPORTANTE en este entorno)
LAN_IF=brint
WAN_IF=net1

echo "Configurando NAT con script VNX..."

# Usar tu mismo script probado
/vnx_config_nat $LAN_IF $WAN_IF

echo "Arrancando FRR..."

if [ -x /usr/lib/frr/frrinit.sh ]; then
  rm -f /var/run/frr/watchfrr.pid
  /usr/lib/frr/frrinit.sh start
fi

echo "CPE listo"

# Mantener contenedor activo
tail -f /dev/null