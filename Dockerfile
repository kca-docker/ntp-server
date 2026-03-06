# Stage 1: Runtime environment
FROM alpine:3.20

# Metadata according to OCI image spec
LABEL org.opencontainers.image.title="Secure NTP Server" \
      org.opencontainers.image.description="Minimal Chrony-based NTP server container" \
      org.opencontainers.image.vendor="ntp-server" \
      org.opencontainers.image.licenses="unlicense"

# Install chrony and remove cache to keep image size small
RUN apk add --no-cache chrony && \
    # Ensure directories exist and permissions are set for the chrony user
    mkdir -p /etc/chrony /var/lib/chrony /var/run/chrony && \
    chown -R chrony:chrony /etc/chrony /var/lib/chrony /var/run/chrony

# Copy hardened configuration with correct ownership
COPY --chown=chrony:chrony chrony.conf /etc/chrony/chrony.conf

# NTP uses port 123 via UDP
EXPOSE 123/udp

# Run as non-root user (BSI SYS.1.6 requirement)
USER chrony

# -d: run in foreground (log to stdout), -f: specify config file
ENTRYPOINT ["/usr/sbin/chronyd"]
CMD ["-d", "-f", "/etc/chrony/chrony.conf"]
