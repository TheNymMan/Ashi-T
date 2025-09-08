# syntax=docker/dockerfile:1.6
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates tmux ttyd tini gosu procps tor torsocks \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash ashigaru

# Copy pre-fetched, verified artifacts from the repo context
# (GitHub Actions job will place them in ./artifacts)
COPY artifacts/ashigaru_terminal_v1.0.0_amd64.deb /tmp/
COPY artifacts/ashigaru_terminal_v1.0.0_signed_hashes.txt /tmp/

# Re-check SHA256 inside the build (defense in depth)
RUN set -e; \
  exp="$(awk '/File name: ashigaru_terminal_v1.0.0_amd64.deb/{getline; print $NF; exit}' \
    /tmp/ashigaru_terminal_v1.0.0_signed_hashes.txt)"; \
  [ -n "$exp" ] && [ "${#exp}" -eq 64 ] || { \
    echo "Failed to parse expected SHA256 from signed_hashes.txt" >&2; exit 1; }; \
  act="$(sha256sum /tmp/ashigaru_terminal_v1.0.0_amd64.deb | awk '{print $1}')"; \
  test "$exp" = "$act"

# Install Ashigaru, resolving deps if needed
RUN set -e; \
  dpkg -i /tmp/ashigaru_terminal_v1.0.0_amd64.deb || \
    (apt-get update && apt-get -f install -y && rm -rf /var/lib/apt/lists/*); \
  rm -f /tmp/ashigaru_terminal_v1.0.0_amd64.deb

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
