FROM ubuntu:22.04 AS fetch
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget gnupg tor torsocks coreutils \
    && rm -rf /var/lib/apt/lists/*

ARG ASHI_VERSION=1.0.0
ARG ARCH=amd64
ARG ONION_HOST=ashicodepbnpvslzsl2bz7l2pwrjvajgumgac423pp3y2deprbnzz7id.onion

# Explicit torrc so Tor can drop privileges and log to stdout
RUN set -eux; \
  printf '%s\n' \
    'RunAsDaemon 0' \
    'User debian-tor' \
    'DataDirectory /var/lib/tor' \
    'ClientOnly 1' \
    'AvoidDiskWrites 1' \
    'SocksPort 127.0.0.1:9050' \
    'Log notice stdout' \
    > /tmp/torrc

# Configure torsocks to use the local Tor
RUN mkdir -p /etc/tor && printf '%s\n' \
  'TorAddress 127.0.0.1' \
  'TorPort 9050' > /etc/tor/torsocks.conf

# Start Tor, wait for SOCKS, download + verify with retries
RUN set -eux; \
  tor -f /tmp/torrc & \
  for i in $(seq 1 60); do \
    bash -c '>/dev/tcp/127.0.0.1/9050' 2>/dev/null && break; \
    sleep 1; \
    if [ "$i" -eq 60 ]; then echo "Tor SOCKS not ready" >&2; exit 1; fi; \
  done; \
  mkdir -p /artifacts; \
  for tries in 1 2 3 4 5; do \
    torsocks wget -O /artifacts/ashigaru.deb \
      "http://${ONION_HOST}/Ashigaru/Ashigaru-Terminal/releases/download/v${ASHI_VERSION}/ashigaru_terminal_v${ASHI_VERSION}_${ARCH}.deb" \
      && break || { echo "retry $tries"; sleep 5; }; \
    if [ "$tries" = 5 ]; then exit 1; fi; \
  done; \
  for tries in 1 2 3 4 5; do \
    torsocks wget -O /artifacts/signed_hashes.txt \
      "http://${ONION_HOST}/Ashigaru/Ashigaru-Terminal/releases/download/v${ASHI_VERSION}/ashigaru_terminal_v${ASHI_VERSION}_signed_hashes.txt" \
      && break || { echo "retry $tries"; sleep 5; }; \
    if [ "$tries" = 5 ]; then exit 1; fi; \
  done; \
  torsocks curl -sS https://keybase.io/ashigarudev/pgp_keys.asc | gpg --import; \
  gpg --verify /artifacts/signed_hashes.txt; \
  exp="$(awk "/File name: ashigaru_terminal_v${ASHI_VERSION}_${ARCH}.deb/{getline; print \$NF; exit}" \
      /artifacts/signed_hashes.txt)"; \
  [ -n "$exp" ] && [ "${#exp}" -eq 64 ] || { echo "Failed to parse SHA256" >&2; exit 1; }; \
  act="$(sha256sum /artifacts/ashigaru.deb | awk '{print $1}')"; \
  test "$exp" = "$act"
