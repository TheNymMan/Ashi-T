# Ashigaru-Terminal Docker Image

## Manual build (Tor + verify + Docker)

These steps show how to clone this repo, download Ashigaru Terminal over Tor, verify signatures and hashes, and build the Docker image locally. The same Dockerfile is used by both GitHub Actions and manual builds.

### Prerequisites (Debian/Ubuntu)
```bash
sudo apt update
sudo apt install -y git docker.io tor torsocks gnupg curl
sudo systemctl enable --now docker
sudo systemctl enable --now tor
```

### Clone this repository
```bash
git clone https://github.com/TheNymMan/Ashi-T.git
cd Ashi-T
```

If this repository contains a VERSION file, you can read the Ashigaru version directly:
```bash
ASHI_VERSION=$(cat VERSION)   # fallback to: ASHI_VERSION=1.0.0
```

Or set it manually:
```bash
ASHI_VERSION=1.0.0
```

### Download Ashigaru artifacts over Tor
Create the artifacts directory and download the amd64 .deb and the signed hashes for the chosen version:
```bash
mkdir -p artifacts
cd artifacts

torsocks wget \
  "http://ashicodepbnpvslzsl2bz7l2pwrjvajgumgac423pp3y2deprbnzz7id.onion/Ashigaru/Ashigaru-Terminal/releases/download/v${ASHI_VERSION}/ashigaru_terminal_v${ASHI_VERSION}_amd64.deb"

torsocks wget \
  "http://ashicodepbnpvslzsl2bz7l2pwrjvajgumgac423pp3y2deprbnzz7id.onion/Ashigaru/Ashigaru-Terminal/releases/download/v${ASHI_VERSION}/ashigaru_terminal_v${ASHI_VERSION}_signed_hashes.txt"

cd ..
```
You can verify the authenticity of these URLs from the official website [ashigaru.rs](https://ashigaru.rs)

### Verify PGP signature and SHA256
Import Ashigaru’s PGP key and verify the signature file:
```bash
curl -sS https://keybase.io/ashigarudev/pgp_keys.asc | gpg --import
gpg --verify "artifacts/ashigaru_terminal_v${ASHI_VERSION}_signed_hashes.txt"
```

Confirm the .deb sha256 matches the signed hashes:
```bash
exp=$(awk "/File name: ashigaru_terminal_v${ASHI_VERSION}_amd64.deb/{getline; print \$NF; exit}" \
  "artifacts/ashigaru_terminal_v${ASHI_VERSION}_signed_hashes.txt")

act=$(sha256sum "artifacts/ashigaru_terminal_v${ASHI_VERSION}_amd64.deb" | awk '{print $1}')

test "$exp" = "$act" && echo "SHA256 OK" || { echo "SHA256 mismatch"; exit 1; }
```

### Build the Docker image
Single-arch build (matches your host architecture):
```bash
docker build \
  --build-arg ASHI_VERSION=${ASHI_VERSION} \
  -t ashigaru-terminal:${ASHI_VERSION} .
```

Optional multi-arch build (requires buildx; publishes a manifest locally):
```bash
# One-time setup (if needed)
docker buildx create --use

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg ASHI_VERSION=${ASHI_VERSION} \
  -t ashigaru-terminal:${ASHI_VERSION} .
```

Note for ARM64 hosts: This image uses the upstream AMD64 Ashigaru build. On arm64 machines, running the image may require host binfmt support for x86_64 (qemu). If missing, an admin can install:
```bash
docker run --privileged --rm tonistiigi/binfmt --install x86_64
```

### Run locally (manual build)
```bash
docker rm -f ashigaru 2>/dev/null || true

docker run -d --name ashigaru \
  -p 127.0.0.1:7682:7682 \
  ashigaru-terminal:${ASHI_VERSION}
```

Open the web UI at:
- http://localhost:7682

## Using the prebuilt image

### Pull
```bash
docker pull ghcr.io/thenymman/ashi-t:latest
# or a specific version:
docker pull ghcr.io/thenymman/ashi-t:1.0.0
```

### Run (localhost-only)
```bash
docker rm -f ashigaru 2>/dev/null || true

docker run -d --name ashigaru \
  -p 127.0.0.1:7682:7682 \
  --restart unless-stopped \
  ghcr.io/thenymman/ashi-t:latest
```

Open the web UI:
- http://localhost:7682

### docker-compose example
Save as docker-compose.yml:
```yaml
services:
  ashigaru:
    image: ghcr.io/thenymman/ashi-t:latest
    container_name: ashigaru
    ports:
      - "127.0.0.1:7682:7682"
    # Optional persistence:
    # volumes:
    #   - ./ashigaru-data:/home/ashigaru
    restart: unless-stopped

# volumes:
#   ashigaru-data:
```

Start:
```bash
docker compose up -d
```

Update to the latest:
```bash
docker pull ghcr.io/thenymman/ashi-t:latest
docker compose up -d
```

## Usage tips and important notes

To paste content into the web terminal use Ctrl+Shift+V on Windows or Linux, or Cmd+Shift+V on macOS. In LibreWolf or Tor Browser, it may be necessary to disable resistFingerprinting for the web terminal to function properly. Alternatively, you can use a Chromium-based browser such as Brave. To connect to an Electrum server over Tor within Ashigaru Terminal, enter the server’s .onion address, select the correct Electrum port, and enable the proxy with the address 127.0.0.1 and port 9050.

Please note that updates may not retain existing wallets. Always back up your seed phrase securely, especially before upgrading or migrating.

Ashigaru Terminal is designed to be used in combination with the Ashigaru Mobile App. The only official website is [ashigaru.rs](https://ashigaru.rs). Any other sites are fraudulent, as are individuals claiming to represent Ashigaru on social media – Ashigaru has no social media presence. Always act responsibly and in compliance with the law. The developers do not assume any responsibility for your actions. Do your own research and make informed decisions.

For learning resources on the Ashigaru stack, you may find the following helpful:
- Ashigaru Terminal overview: [ashigaru.rs/docs/ashigaru-terminal-overview](https://ashigaru.rs/docs/ashigaru-terminal-overview)
- Whirlpool guide: [k3tan.com/ashigaru-whirlpool](https://k3tan.com/ashigaru-whirlpool)
- Video: [youtube.com/watch?v=aykJ4eP-Veo](https://www.youtube.com/watch?v=aykJ4eP-Veo)
- Video: [youtube.com/watch?v=ULZoPMCYPfk](https://www.youtube.com/watch?v=ULZoPMCYPfk)
