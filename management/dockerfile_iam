
FROM ibmcom/iam:latest

# Headers
LABEL  description="IBM Domino Server 10 with IAM (AppDevPack)" \
  vendor="NashCom" \
  maintainer="Daniel Nashed <nsh@nashcom.de>" 

ARG DownloadFrom=

USER root

COPY install_dir /tmp/install_dir

HEALTHCHECK --interval=60s --timeout=10s CMD /domino_docker_healthcheck.sh

RUN  yum update -y && \
  /tmp/install_dir/install.sh && \
  yum clean all >/dev/null && \
  rm -fr /var/cache/yum && \
  rm -rf /tmp/install_dir

# Expose Ports HTTP HTTPS IAM-ADMIN

EXPOSE 80 443 8443

ENTRYPOINT ["/domino_docker_entrypoint.sh"]
