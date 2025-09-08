# syntax=docker/dockerfile:1.6

############################
# Stage 1: fetch + verify over Tor
############################
FROM ubuntu:22.04 AS fetch
ENV DEBIAN_FRONTEND=noninteractive

# Tools for fetching/verifying
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget gnupg tor torsocks coreutils \
    && rm -rf /var/lib/apt/lists/*

# Build args for version/arch and onion host
ARG ASHI_VERSION=1.0.0
ARG ARCH=amd64
ARG ONION_HOST=ashicodepbnpvslzsl2pwrjvajgumgac423pp3y2deprbnzz7id.onion

# Minimal torsocks config (route via local tor)
RUN mkdir -p /etc/tor && printf '%s\n' \
  'TorAddress 127.0.0.1' \
  'TorPort 9050' > /etc/tor/torsocks.conf

# Start tor, wait for SOCKS, fetch artifacts via torsocks, verify PGP + SHA256
RUN set -eux; \
  tor -f /etc/tor/torrc & \
  for i in $(seq 1 30); do \
    bash -c '>/dev/tcp/127.0.0.1/9050' && break; sleep 1; \
  done; \
  mkdir -p /artifacts; \
  torsocks wget -O /artifacts/ashigaru.deb \
    "http://${ONION_HOST}/Ashigaru/Ashigaru-Terminal/releases/download/v${ASHI_VERSION}/ashigaru_terminal_v${ASHI_VERSION}_${ARCH}.deb"; \
  torsocks wget -O /artifacts/signed_hashes.txt \
    "http://${ONION_HOST}/Ashigaru/Ashigaru-Terminal/releases/download/v${ASHI_VERSION}/ashigaru_terminal_v${ASHI_VERSION}_signed_hashes.txt"; \
  torsocks curl -sS https://keybase.io/ashigarudev/pgp_keys.asc | gpg --import; \
  gpg --verify /artifacts/signed_hashes.txt; \
  exp="$(awk "/File name: ashigaru_terminal_v${ASHI_VERSION}_${ARCH}.deb/{getline; print $NF; exit}" \
      /artifacts/signed_hashes.txt)"; \
  [ -n "$exp" ] && [ "${#exp}" -eq 64 ]; \
  act="$(sha256sum /artifacts/ashigaru.deb | awk '{print $1}')"; \
  test "$exp" = "$act"

############################
# Stage 2: final runtime
############################
FROM ubuntu:22.04 AS runtime
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates tmux ttyd tini gosu procps tor torsocks \
    && rm -rf /var/lib/apt/lists/*

# Non-root user
RUN useradd -m -u 1000 -s /bin/bash ashigaru

# Bring in verified .deb from fetch stage and install
COPY --from=fetch /artifacts/ashigaru.deb /tmp/ashigaru.deb
# (Optional) re-check SHA against the signed file again in runtime stage
COPY --from=fetch /artifacts/signed_hashes.txt /tmp/signed_hashes.txt
RUN set -e; \
  exp="$(awk '/File name:/{f=$0} END{print}' /tmp/signed_hashes.txt >/dev/null 2>&1; \
    awk '/File name: ashigaru_terminal/{getline; print $NF; exit}' /tmp/signed_hashes.txt)"; \
  [ -n "$exp" ] && [ "${#exp}" -eq 64 ] || true; \
  act="$(sha256sum /tmp/ashigaru.deb | awk '{print $1}')"; \
  if [ -n "$exp" ]; then test "$exp" = "$act"; fi; \
  dpkg -i /tmp/ashigaru.deb || (apt-get update && apt-get -f install -y && rm -rf /var/lib/apt/lists/*); \
  rm -f /tmp/ashigaru.deb

# Runtime env
ENV TERM=xterm-256color \
    TMUX_SESSION=ashigaru \
    PORT=7682 \
    ASHIGARU_CMD=/opt/ashigaru-terminal/bin/Ashigaru-terminal \
    TOR_SOCKS_LISTEN=127.0.0.1 \
    TOR_SOCKS_PORT=9050 \
    TOR_CONTROL_ENABLE=0 \
    TOR_CONTROL_LISTEN=127.0.0.1 \
    TOR_CONTROL_PORT=9051 \
    TOR_DATADIR=/home/ashigaru/.tor

# Entrypoint
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 7682
EXPOSE 9050
EXPOSE 9051

WORKDIR /home/ashigaru
USER ashigaru

ENTRYPOINT ["/usr/bin/tini","--","/usr/local/bin/docker-entrypoint.sh"]
