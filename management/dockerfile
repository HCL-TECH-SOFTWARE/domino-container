
FROM ibmcom/domino:latest

# Headers
LABEL description="IBM Domino Server 10 Acme Customized" \
  vendor="NashCom" \
  maintainer="Daniel Nashed <nsh@nashcom.de>" 

ARG DownloadFrom=
ARG DominoResponseFile=domino10_response.dat

USER root

COPY install_dir /tmp/install_dir

HEALTHCHECK --interval=60s --timeout=10s CMD /domino_docker_healthcheck.sh

RUN yum update -y && \
  /tmp/install_dir/install.sh && \
  yum clean all >/dev/null && \
  rm -fr /var/cache/yum && \
  rm -rf /tmp/install_dir

# Expose Ports NRPC HTTP POP3 IMAP LDAP HTTPS LDAPS IMAPS POP3S DIIOP DIIOPS

EXPOSE 1352 80 110 143 389 443 636 993 995 63148 63149 

ENTRYPOINT ["/domino_docker_entrypoint.sh"]

USER notes

