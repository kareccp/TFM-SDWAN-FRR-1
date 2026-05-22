#!/bin/bash

# start_corpcpe.sh (versión corregida)
#
# Requiere variables:
# KUBECTL, SDWNS, NETNUM, VACC, VCPE, CUSTUNIP, CUSTPREFIX, VNFTUNIP, VCPEPUBIP, VCPEGW
#
# Esta versión:
# - resuelve deployments -> pods
# - espera a que los pods estén Ready
# - determina el nombre del contenedor dentro del pod y lo usa con -c

set -euo pipefail

: ${KUBECTL:?KUBECTL no definido}
: ${SDWNS:?SDWNS no definido}
: ${NETNUM:?NETNUM no definido}
: ${VACC:?VACC no definido}
: ${VCPE:?VCPE no definido}
: ${CUSTUNIP:?CUSTUNIP no definido}
: ${CUSTPREFIX:?CUSTPREFIX no definido}
: ${VNFTUNIP:?VNFTUNIP no definido}
: ${VCPEPUBIP:?VCPEPUBIP no definido}
: ${VCPEGW:?VCPEGW no definido}

# helper: resolver un "id" que puede ser:
# - deploy/<deployment_id>
# - <deployment_id> (deploy/ omitido)
# - <pod_full_name>
# Devuelve el pod full name (ej: access1-accesschart-xxxxx)
resolve_pod() {
  local id="$1" namespace="$2"
  local base

  # si viene en formato "deploy/<name>" o "deployment/<name>"
  if [[ "$id" =~ ^deploy/ ]] || [[ "$id" =~ ^deployment/ ]]; then
    base="${id#*/}"
  else
    base="$id"
  fi

  # Si ya es un pod (contiene un sufijo tipo -xxxx) y existe, lo dejamos
  if $KUBECTL get pod -n "$namespace" "$base" >/dev/null 2>&1; then
    echo "$base"
    return 0
  fi

  # Buscar pods cuyo nombre contenga la base (por ejemplo access1-accesschart)
  # Esperar a que aparezca algún pod hasta un timeout corto
  local pod
  for i in {1..12}; do
    pod=$($KUBECTL get pods -n "$namespace" -o name 2>/dev/null | grep -E "/${base}" | head -n1 | cut -d'/' -f2 || true)
    if [[ -n "$pod" ]]; then
      echo "$pod"
      return 0
    fi
    sleep 2
  done

  # última oportunidad: buscar por substring
  pod=$($KUBECTL get pods -n "$namespace" -o name 2>/dev/null | grep -E "${base}" | head -n1 | cut -d'/' -f2 || true)
  if [[ -n "$pod" ]]; then
    echo "$pod"
    return 0
  fi

  return 1
}

# helper: obtener nombre del contenedor principal del pod
get_container_name() {
  local pod="$1" namespace="$2"
  $KUBECTL get pod "$pod" -n "$namespace" -o jsonpath="{.spec.containers[0].name}" 2>/dev/null || true
}

echo "## 1. Resolviendo pods a partir de VACC='$VACC' VCPE='$VCPE' en namespace '$SDWNS'"

POD_ACCESS=$(resolve_pod "$VACC" "$SDWNS") || {
  echo "ERROR: no pude resolver pod para VACC='$VACC' en ns='$SDWNS'"; exit 2;
}
POD_CPE=$(resolve_pod "$VCPE" "$SDWNS") || {
  echo "ERROR: no pude resolver pod para VCPE='$VCPE' en ns='$SDWNS'"; exit 3;
}

echo "Pod access detectado: $POD_ACCESS"
echo "Pod cpe detectado:    $POD_CPE"

# Esperar a que ambos pods estén Ready (timeout total 120s)
echo "Esperando a que los pods estén Ready..."
$KUBECTL wait --for=condition=Ready pod/"$POD_ACCESS" -n "$SDWNS" --timeout=120s || {
  echo "ERROR: pod $POD_ACCESS no llegó a Ready"; exit 4;
}
$KUBECTL wait --for=condition=Ready pod/"$POD_CPE" -n "$SDWNS" --timeout=120s || {
  echo "ERROR: pod $POD_CPE no llegó a Ready"; exit 5;
}

# determinar nombres de contenedor (por si hay más de uno)
ACC_CONT=$(get_container_name "$POD_ACCESS" "$SDWNS")
CPE_CONT=$(get_container_name "$POD_CPE" "$SDWNS")

if [[ -z "$ACC_CONT" ]]; then
  echo "ERROR: no pude obtener nombre del contenedor en pod $POD_ACCESS"; exit 6;
fi
if [[ -z "$CPE_CONT" ]]; then
  echo "ERROR: no pude obtener nombre del contenedor en pod $POD_CPE"; exit 7;
fi

echo "Contenedor en access: $ACC_CONT"
echo "Contenedor en cpe:    $CPE_CONT"

ACC_EXEC="$KUBECTL exec -n $SDWNS $POD_ACCESS -c $ACC_CONT --"
CPE_EXEC="$KUBECTL exec -n $SDWNS $POD_CPE -c $CPE_CONT --"

# IP privada por defecto para el vCPE
VCPEPRIVIP="192.168.255.254"
# IP privada por defecto para el router del cliente
CUSTGW="192.168.255.253"

# Router por defecto inicial en k8s (calico)
K8SGW="169.254.1.1"

## 1. Obtener IPs de las VNFs
echo "## 1. Obtener IPs de las VNFs"
IPACCESS=$($ACC_EXEC hostname -I | awk '{print $1}')
echo "IPACCESS = $IPACCESS"

IPCPE=$($CPE_EXEC hostname -I | awk '{print $1}')
echo "IPCPE = $IPCPE"

## 2. Iniciar el Servicio OpenVirtualSwitch en cada VNF:
echo "## 2. Iniciar el Servicio OpenVirtualSwitch en cada VNF"
$ACC_EXEC service openvswitch-switch start || echo "Advertencia: fallo al iniciar OVS en $POD_ACCESS"
$CPE_EXEC service openvswitch-switch start || echo "Advertencia: fallo al iniciar OVS en $POD_CPE"

## 3. En VNF:access agregar un bridge y configurar IPs y rutas
echo "## 3. En VNF:access agregar un bridge y configurar IPs y rutas"
$ACC_EXEC ovs-vsctl add-br brint
$ACC_EXEC ifconfig net$NETNUM "$VNFTUNIP/24"
$ACC_EXEC ip link add vxlan2 type vxlan id 2 remote "$CUSTUNIP" dstport 8742 dev net$NETNUM
$ACC_EXEC ip link add axscpe type vxlan id 4 remote "$IPCPE" dstport 8742 dev eth0
$ACC_EXEC ovs-vsctl add-port brint vxlan2
$ACC_EXEC ovs-vsctl add-port brint axscpe
$ACC_EXEC ifconfig vxlan2 up
$ACC_EXEC ifconfig axscpe up

## 4. En VNF:cpe agregar un bridge y configurar IPs y rutas
echo "## 4. En VNF:cpe agregar un bridge y configurar IPs y rutas"
$CPE_EXEC ovs-vsctl add-br brint
$CPE_EXEC ifconfig brint "$VCPEPRIVIP/24"
$CPE_EXEC ip link add axscpe type vxlan id 4 remote "$IPACCESS" dstport 8742 dev eth0
$CPE_EXEC ovs-vsctl add-port brint axscpe
$CPE_EXEC ifconfig axscpe up
$CPE_EXEC ifconfig brint mtu 1400
$CPE_EXEC ifconfig net$NETNUM "$VCPEPUBIP/24"
$CPE_EXEC ip route add "$IPACCESS/32" via "$K8SGW"
$CPE_EXEC ip route del 0.0.0.0/0 via "$K8SGW" || true
$CPE_EXEC ip route add 0.0.0.0/0 via "$VCPEGW"
$CPE_EXEC ip route add "$CUSTPREFIX" via "$CUSTGW"

## 5. En VNF:cpe activar NAT para dar salida a Internet
echo "## 5. En VNF:cpe activar NAT para dar salida a Internet"
$CPE_EXEC /vnx_config_nat brint net$NETNUM || echo "Advertencia: fallo al configurar NAT en $POD_CPE"

echo "Configuración completada."