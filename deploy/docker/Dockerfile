# syntax=docker/dockerfile:1.7

FROM nginxinc/nginx-unprivileged:1.31-alpine

LABEL org.opencontainers.image.title="Bikram Sarkar Portfolio" \
      org.opencontainers.image.description="Hardened non-root static portfolio served by Nginx on GKE Autopilot" \
      org.opencontainers.image.url="https://bikramsarkar.space" \
      org.opencontainers.image.source="https://github.com/sarkarbikram90/bikramsarkar-portfolio"

# Remove default static files
RUN rm -rf /usr/share/nginx/html/*

# Copy hardened Nginx configuration
COPY --chown=10101:10101 deploy/docker/nginx/nginx.conf /etc/nginx/nginx.conf
COPY --chown=10101:10101 deploy/docker/nginx/security-headers.conf /etc/nginx/snippets/security-headers.conf
COPY --chown=10101:10101 deploy/docker/nginx/default.conf /etc/nginx/conf.d/default.conf

# Copy static website assets explicitly (avoid leaking repo/IaC files)
COPY --chown=10101:10101 index.html 404.html profile.png favicon.svg favicon.png favicon.ico Bikram_Sarkar_DevOps_SRE_Resume.pdf /usr/share/nginx/html/
COPY --chown=10101:10101 assets/ /usr/share/nginx/html/assets/

EXPOSE 8080

# Non-root UID/GID > 10000 to avoid host user-table overlap (KSV-0020 / KSV-0021)
USER 10101:10101

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/healthz >/dev/null 2>&1 || exit 1

# Bypass /docker-entrypoint.sh so readOnlyRootFilesystem=true works cleanly
ENTRYPOINT ["nginx"]
CMD ["-g", "daemon off;"]
