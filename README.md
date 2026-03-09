- [Secure NTP Server (Chrony)](#secure-ntp-server-chrony)
  - [Features](#features)
  - [Configuration](#configuration)
- [Start the container](#start-the-container)
  - [Recommended: Persistence \& Security](#recommended-persistence--security)
    - [Persistence](#persistence)
    - [Security Hardening](#security-hardening)
  - [Monitoring](#monitoring)
    - [Check Health Status](#check-health-status)
    - [Chrony Statistics](#chrony-statistics)
  - [Best practices](#best-practices)


# Secure NTP Server (Chrony)

A minimal, hardened NTP server container based on **Alpine Linux** and **Chrony**. This project follows security best practices, including non-root execution (BSI SYS.1.6 requirement) and restricted container capabilities.

## Features
- **Security-First**: Runs as a non-privileged user (`chrony`).
- **Read-Only Ready**: Designed to serve time without affecting the host system clock.
- **Lightweight**: Minimal image size based on Alpine 3.20.
- **Health Monitored**: Includes built-in healthchecks via `chronyc`.

## Configuration

The image uses the following `chrony.conf`. It is configured to act as a pure time provider (Relay) without attempting to modify the host clock.

```text
# Use public NTP pool servers
server 0.de.pool.ntp.org iburst
server 1.de.pool.ntp.org iburst

# Record the rate at which the system clock gains/losses time
driftfile /var/lib/chrony/chrony.drift

# Hardware clock settings (Disabled for unprivileged containers)
proc_systime 0
nosystemclock

# Access control: Allow local networks
allow 10.0.0.0/8
allow 172.16.0.0/12
allow 192.168.0.0/16

logchange 0.5
```

# Start the container

```bash
docker run -d \
  --name ntp-server \
  -p 123:123/udp \
  secure-ntp-server
```

## Recommended: Persistence & Security

For production environments, it is highly recommended to use a persistent volume for the drift file and to further restrict the container's privileges.

### Persistence

The ```driftfile``` allows Chrony to track the clock's error rate. Without a volume, this information is lost on restart, leading to longer synchronization times.

### Security Hardening

Since this container is configured with ```nosystemclock```, it does not require ```CAP_SYS_TIME```. You can safely drop all capabilities.

**Optimized Run Command**:
```bash
docker run -d \
  --name ntp-server \
  -p 123:123/udp \
  --read-only \
  --tmpfs /tmp \
  --tmpfs /var/run/chrony \
  -v ntp-data:/var/lib/chrony \
  --cap-drop=ALL \
  --security-opt no-new-privileges \
  secure-ntp-server
```

- ```--read-only```: Protects the root filesystem.
- ```-v ntp-data:/var/lib/chrony```: Persists the drift statistics.
- ```--cap-drop=ALL```: Removes all kernel privileges.

## Monitoring

You can monitor the NTP server's health and synchronization status using the following commands.

### Check Health Status

The container includes a Docker Healthcheck. Check the status via:

```bash
docker inspect --format='{{json .State.Health}}' ntp-server
```

### Chrony Statistics

To see details about the upstream servers and time accuracy:

```bash
# Show synchronization status
docker exec ntp-server chronyc tracking

# Show list of NTP sources
docker exec ntp-server chronyc sources -v

# Show statistics about the sources
docker exec ntp-server chronyc sourcestats -v
```

## Best practices

**docker-compose.yaml**
```yaml
### Using Docker Compose (Recommended)
Create a `docker-compose.yaml` to run the official image with hardened security settings:

```yaml
services:
  ntp-server:
    image: bksolutions/ntp-server:latest
    container_name: ntp-server
    restart: unless-stopped
    ports:
      - "123:123/udp"
    read_only: true
    tmpfs:
      - /tmp
      - /var/run/chrony:uid=100,gid=101
    volumes:
      - ntp-data:/var/lib/chrony
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
```

To ensure maximum security and efficiency, the following parameters are used in the Compose setup:

- ```read_only```: true: This is the strongest hardening for the filesystem, preventing any unauthorized persistent changes.
- ```tmpfs```: Since Chrony creates Unix sockets in /var/run/chrony at runtime, we mount this as volatile memory. The uid/gid settings ensure the chrony user has write access.
- ```ntp-data``` (Volume): This persists the chrony.drift file. It ensures the server remembers the clock's error rate after a restart, avoiding the need to recalculate time offset from scratch.
- ```cap_drop: ALL```: Since the container does not need to set the host clock, all kernel capabilities are removed to minimize the attack surface.