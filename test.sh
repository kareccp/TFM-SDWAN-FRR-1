#!/bin/bash
echo "------------- Pruebas de Conectividad -------------"
cd ~/shared/sdedge-ns/vnx
echo "------------- Ping desde h1 hacia t1 y hacia r1 -------------"
sudo vnx -f sdedge_nfv.xml --exe-cli "ping -c3 10.20.1.200" -M h1
sudo vnx -f sdedge_nfv.xml --exe-cli "ping -c3 10.20.1.1" -M h1

echo "------------- Conectividad h1 OK -------------"
echo "------------- Ping desde t1 hacia h1 y hacia r1 -------------"
sudo vnx -f sdedge_nfv.xml --exe-cli "ping -c3 10.20.1.2" -M t1
sudo vnx -f sdedge_nfv.xml --exe-cli "ping -c3 10.20.1.1" -M t1
echo "------------- Conectividad t1 OK-------------"

echo "------------- Ping desde r1 hacia h1 y hacia t1 -------------"
sudo vnx -f sdedge_nfv.xml --exe-cli "ping -c3 10.20.1.2" -M r1
sudo vnx -f sdedge_nfv.xml --exe-cli "ping -c3 10.20.1.200" -M r1
echo "------------- Conectividad r1 OK-------------"

echo "------------- Pruebas de Conectividad en el segmento de Internet -------------"
echo "------------- Ping desder isp1 hacia isp2 y hacia s1-------------"
sudo vnx -f sdedge_nfv.xml --exe-cli "ping -c3 10.100.3.2" -M isp1
sudo vnx -f sdedge_nfv.xml --exe-cli "ping -c3 10.100.3.3" -M isp1
echo "------------- Conectividad isp1 OK-------------"

echo "------------- Ping desder isp2 hacia isp1 y hacia s1 -------------"
sudo vnx -f sdedge_nfv.xml --exe-cli "ping -c3 10.100.3.1" -M isp2
sudo vnx -f sdedge_nfv.xml --exe-cli "ping -c3 10.100.3.3" -M isp2
echo "------------- Conectividad isp2 OK-------------"

echo "------------- Ping desder s1 hacia isp1 y hacia isp2 -------------"
sudo vnx -f sdedge_nfv.xml --exe-cli "ping -c3 10.100.3.1" -M s1
sudo vnx -f sdedge_nfv.xml --exe-cli "ping -c3 10.100.3.2" -M s1
echo "------------- Conectividad s1 OK-------------"

echo "------------- Acceso desde s1 hacia 8.8.8.8 -------------"
sudo vnx -f sdedge_nfv.xml --exe-cli "ping -c3 8.8.8.8" -M s1
echo "------------- Conectividad Internet OK-------------"

