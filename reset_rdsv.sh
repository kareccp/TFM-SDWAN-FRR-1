#!/bin/bash

NAMESPACE="rdsv"
K="microk8s kubectl"

echo "======================================="
echo " RESET COMPLETO DEL ENTORNO RDSV"
echo "======================================="

# ----------------------------------
echo "[1] Desinstalando releases Helm..."
# ----------------------------------
helm uninstall access1 -n $NAMESPACE 2>/dev/null
helm uninstall cpe1 -n $NAMESPACE 2>/dev/null
helm uninstall wan1 -n $NAMESPACE 2>/dev/null
helm uninstall access2 -n $NAMESPACE 2>/dev/null
helm uninstall cpe2 -n $NAMESPACE 2>/dev/null
helm uninstall wan2 -n $NAMESPACE 2>/dev/null

sleep 2

# ----------------------------------
echo "[2] Eliminando deployments..."
# ----------------------------------
$K delete deployments --all -n $NAMESPACE --ignore-not-found

# ----------------------------------
echo "[3] Eliminando replicasets..."
# ----------------------------------
$K delete replicaset --all -n $NAMESPACE --ignore-not-found

# ----------------------------------
echo "[4] Eliminando servicios..."
# ----------------------------------
$K delete svc --all -n $NAMESPACE --ignore-not-found

# ----------------------------------
echo "[5] Eliminando pods normales..."
# ----------------------------------
$K delete pods --all -n $NAMESPACE --ignore-not-found

sleep 2

# ----------------------------------
echo "[6] Eliminando pods en Terminating..."
# ----------------------------------
pods=$($K get pods -n $NAMESPACE | grep Terminating | awk '{print $1}')

for pod in $pods; do
    echo "Forzando eliminación de $pod"
    $K delete pod $pod -n $NAMESPACE --force --grace-period=0
done

sleep 2

# ----------------------------------
echo "[7] Estado general..."
# ----------------------------------

echo "[8] Verificando pods finales..."
pods=$($K get pods -n $NAMESPACE 2>/dev/null)

if [ -z "$pods" ] || echo "$pods" | grep -q "No resources found"; then
    echo "✅ No hay pods en el namespace (limpieza completa)"
else
    echo "$pods"
    echo "⚠️  Aún quedan recursos activos"
fi


# ----------------------------------
echo "[8] Verificando pods finales..."
# ----------------------------------

