# syntax=docker/dockerfile:1.6
FROM ubuntu:22.04

# Add build args for version and icon URL (adjust defaults)
ARG ASHI_VERSION=1.0.0
ARG ICON_URL="https://raw.githubusercontent.com/TheNymMan/Ashi-T/refs/heads/main/assets/icon.png"
ARG TARGETARCH

# OCI metadata + Portainer icon
LABEL org.opencontainers.image.title="Ashigaru Terminal (ttyd + Tor)" \
      org.opencontainers.image.description="Ashigaru Terminal in a tmux session, served via ttyd, with a built-in Tor SOCKS proxy." \
      org.opencontainers.image.url="https://ashigaru.rs" \
      org.opencontainers.image.source="https://github.com/TheNymMan/Ashi-T" \
      org.opencontainers.image.version="${ASHI_VERSION}" \
      org.opencontainers.image.licenses="MIT" \
      io.portainer.icon="${ICON_URL}"

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates tmux ttyd tini gosu procps tor torsocks \
    && rm -rf /var/lib/apt/lists/*

# If building the arm64 variant, prepare qemu-user emulation and multiarch libs
RUN set -eux; \
  if [ "${TARGETARCH:-}" = "arm64" ]; then \
    apt-get update; \
    apt-get install -y --no-install-recommends qemu-user-static; \
    dpkg --add-architecture amd64; \
    apt-get update; \
  fi; \
  rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash ashigaru

# Bring in artifacts (the workflow fetches these)
# amd64 .deb is used for both variants; arm64 runs it via qemu + multiarch libs
COPY artifacts/ashigaru_terminal_v${ASHI_VERSION}_amd64.deb /tmp/ashigaru_amd64.deb
COPY artifacts/ashigaru_terminal_v${ASHI_VERSION}_signed_hashes.txt /tmp/signed_hashes.txt

# Verify SHA256 and install the amd64 package (works on amd64; on arm64 relies on qemu+multiarch)
RUN set -eux; \
  # Normalize line endings in case the signed file has CRLF
  sed -i 's/\r$//' /tmp/signed_hashes.txt; \
  NAME="ashigaru_terminal_v${ASHI_VERSION}_amd64.deb"; \
  # Parse the expected SHA256 from the line after the matching file name
  exp="$(awk -v n="$NAME" '$0 ~ "File name: " n {getline; print $NF; exit}' /tmp/signed_hashes.txt)"; \
  echo "Expected SHA256 for $NAME: ${exp:-<empty>}"; \
  if [ -z "${exp:-}" ] || [ "${#exp}" -ne 64 ]; then \
    echo "Failed to parse a 64-char SHA256 for $NAME from /tmp/signed_hashes.txt" >&2; \
    echo "Signed file content follows for debugging:" >&2; \
    cat /tmp/signed_hashes.txt >&2; \
    exit 1; \
  fi; \
  act="$(sha256sum /tmp/ashigaru_amd64.deb | awk '{print $1}')"; \
  echo "Actual SHA256: ${act}"; \
  test "$exp" = "$act" || { echo "SHA256 mismatch"; exit 1; }; \
  # Install .deb (on arm64 this relies on qemu-user-static + dpkg multiarch setup done earlier)
  dpkg -i /tmp/ashigaru_amd64.deb || \
    (apt-get update && apt-get -f install -y && rm -rf /var/lib/apt/lists/*); \
  rm -f /tmp/ashigaru_amd64.deb

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
