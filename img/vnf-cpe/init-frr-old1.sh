#!/bin/bash

set -xe

# Log para debug
exec > /tmp/init-frr.log 2>&1

echo "Iniciando CPE con FRR..."

# Activar forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Esperar interfaces
sleep 5

echo "Interfaces detectadas:"
ip a

# Interfaces reales del entorno
LAN_IF=brint
WAN_IF=net1

echo "Intentando configurar NAT con vnx_config_nat..."

# Intentar NAT con script original
/vnx_config_nat $LAN_IF $WAN_IF || echo "vnx_config_nat falló"

echo "Verificando reglas NAT..."

iptables -t nat -L -v

# Comprobar si MASQUERADE está presente
iptables -t nat -L | grep MASQUERADE

if [ $? -ne 0 ]; then
  echo "No hay NAT → aplicando configuración manual..."

  iptables -t nat -A POSTROUTING -o $WAN_IF -j MASQUERADE
  iptables -A FORWARD -i $WAN_IF -o $LAN_IF -m state --state RELATED,ESTABLISHED -j ACCEPT
  iptables -A FORWARD -i $LAN_IF -o $WAN_IF -j ACCEPT

else
  echo "NAT configurado correctamente por el script"
fi

echo "Arrancando FRR..."

if [ -x /usr/lib/frr/frrinit.sh ]; then
  rm -f /var/run/frr/watchfrr.pid
  /usr/lib/frr/frrinit.sh start
fi

echo "CPE listo y funcionando"

# Mantener contenedor activo
tail -f /dev/null
``