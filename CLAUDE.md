# CLAUDE.md

## Project Overview

Docker image + Pterodactyl egg for SA-MP servers with SampVoice support. Solves the random UDP voice port problem by running a transparent UDP proxy inside the container that detects the internal voice port and forwards it to the panel-assigned external port.

## Architecture

```
Pterodactyl assigns:  port 7777 (game)  +  port 7070 (voice)
                              |                    |
                     Container starts      entrypoint.sh writes
                     SA:MP on 7777         config with port 7070
                              |                    |
                     SampVoice spawns       If voice binds to
                     voice server           random port (e.g. 8324)
                              |                    |
                              +--- socat proxy: 7070 -> 8324
                              |
                     Client connects to 7070, proxy forwards to 8324
```

## File Structure

- **`docker/Dockerfile`** — Ubuntu 22.04 base with 32-bit libs + socat
- **`docker/entrypoint.sh`** — Starts SA:MP, detects voice port, runs UDP proxy
- **`egg-samp-voice.json`** — Pterodactyl egg with VOICE_PORT variable
- **`.github/workflows/docker-publish.yml`** — Builds and pushes image to GHCR

## How the Proxy Works

1. Entrypoint writes SampVoice config files (`control.cfg`, `voice.cfg`) with the allocated voice port
2. Records existing UDP ports before starting SA:MP
3. Starts SA:MP server in background
4. Polls for new UDP ports (up to 30 seconds)
5. If voice server bound to a different port than allocated, starts socat UDP proxy
6. Waits for SA:MP process

## Key Constraints

- Do not add comments to source code files
- Docker image must be compatible with Pterodactyl/Pelican panel conventions
- The `container` user (UID 1000) is standard for Pterodactyl
- Voice port must be allocated as a secondary port in the Pterodactyl panel
- The egg's VOICE_PORT variable must match the panel-allocated secondary port

## Build and Test

```bash
cd docker
docker build -t samp-voice:latest .
docker run -e SERVER_PORT=7777 -e VOICE_PORT=7070 -p 7777:7777/udp -p 7070:7070/udp samp-voice:latest
```

## Deployment

1. Push to GitHub to trigger the Docker image build via GitHub Actions
2. Import `egg-samp-voice.json` into Pterodactyl panel
3. Update the `docker_images` field in the egg with the actual GHCR path
4. Create a server, allocate primary port (game) + secondary port (voice)
5. Set the VOICE_PORT variable to match the secondary allocation
