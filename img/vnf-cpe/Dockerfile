FROM quay.io/frrouting/frr:master

RUN apk update && \
    apk add --no-cache iproute2 iptables tcpdump libpcap && \
    ln -sf /sbin/iptables /usr/sbin/iptables && \
    ln -sf /sbin/iptables-save /usr/sbin/iptables-save

COPY daemons /etc/frr/daemons
COPY frr.conf /etc/frr/frr.conf
COPY vnx_config_nat /vnx_config_nat
COPY init-frr.sh /init-frr.sh

RUN chmod +x /vnx_config_nat /init-frr.sh

CMD ["/init-frr.sh"]