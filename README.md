# Ashi-T Docker Image
Run Ashi T via docker

## Overview

This image runs Ashigaru Terminal inside a container and serves it to your browser via ttyd on port 7682. The container includes a Tor SOCKS proxy so Ashigaru can reach .onion Electrum servers.

## Prerequisites

- Docker installed and running

## Pull the image

```bash
docker pull ghcr.io/thenymman/ashi-t:edge@sha256:3c71a278c0a8c8f6971374fbd0eba0b416dbe1ccdb83d34452d82ed89e164b5d
```

## Run locally (binds to localhost)

```bash
docker rm -f ashigaru 2>/dev/null || true

docker run -d --name ashigaru \
  -p 127.0.0.1:7682:7682 \
  ghcr.io/thenymman/ashi-t:edge@sha256:3c71a278c0a8c8f6971374fbd0eba0b416dbe1ccdb83d34452d82ed89e164b5d
```

## Open the web UI

- Visit: http://localhost:7682

## Using Ashigaru Terminal in the browser

- Pasting into the terminal: use Ctrl+Shift+V
- Browsers:
    - LibreWolf / Tor Browser: you may need to disable resistFingerprinting to use the web terminal properly
    - Alternatively, use a Chromium-based browser like Brave

## Connect to any Electrum server over Tor

Inside Ashigaru Terminal’s Electrum settings:
- Enter the server’s .onion address
- Set the correct Electrum port
- Enable proxy and set:
    - Proxy address: 127.0.0.1
    - Proxy port: 9050

Note: The container includes a Tor SOCKS proxy listening at 127.0.0.1:9050 inside the container, so Ashigaru can connect to .onion servers through Tor.

## Update to the latest image

```bash
docker pull ghcr.io/thenymman/ashi-t:edge
docker rm -f ashigaru 2>/dev/null || true
docker run -d --name ashigaru \
  -p 127.0.0.1:7682:7682 \
  ghcr.io/thenymman/ashi-t:edge
```

## Responsibility and legal

- Always do your own research and make decisions based on your own informed judgment
- Use this software responsibly and legally
- I am not responsible for how you use this container or any outcomes from its use
