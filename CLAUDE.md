# CLAUDE.md

## Project Overview

Docker image + Pterodactyl egg for SA-MP servers with SampVoice support. Solves the random UDP voice port problem using a 32-bit LD_PRELOAD hook that forces SampVoice to bind to the panel-assigned port.

## Architecture

```
Pterodactyl assigns:  port 7778 (game)  +  port 7070 (voice)
                              |                    |
                     Container starts      LD_PRELOAD loads
                     SA:MP on 7778         voicefix.so (i386)
                              |                    |
                     SampVoice calls       Hook intercepts:
                     bind(port=0)          bind(port=7070) instead
                              |                    |
                     SampVoice announces   Client connects to
                     port 7070 via RakNet  server_ip:7070 ✓
```

## Why LD_PRELOAD (not socat proxy)

SampVoice v3.1 hardcodes `bind(port=0)` AND announces the bound port to clients via RakNet `ServerInfoPacket`. A socat proxy on 7070→random_port doesn't help because the CLIENT is told to connect to the random port (not 7070). The hook forces SampVoice to bind to the correct port, so the announcement is also correct.

## File Structure

- **`docker/Dockerfile`** — Multi-stage build: i386/debian compiles voicefix.so, parkervcp/games:samp runs SA:MP
- **`docker/voicefix.c`** — LD_PRELOAD hook that intercepts bind() for UDP port 0
- **`docker/entrypoint.sh`** — Sets LD_PRELOAD, starts SA:MP, monitors voice port, socat fallback
- **`egg-samp.json`** — Pterodactyl egg with VOICE_PORT variable
- **`.github/workflows/docker-publish.yml`** — Builds and pushes image to GHCR

## How the Hook Works

1. `voicefix.c` is compiled as a native i386 shared library (multi-stage Docker build)
2. Entrypoint sets `SV_VOICE_PORT=7070` and `LD_PRELOAD=/usr/lib/voicefix.so`
3. SA:MP server starts (32-bit ELF), dynamic linker loads voicefix.so
4. When SampVoice calls `bind(SOCK_DGRAM, INADDR_ANY, port=0)`, hook redirects to port 7070
5. Hook disables itself after first redirect (`unsetenv`) to avoid affecting other sockets
6. SampVoice's `getsockname()` returns 7070, announces 7070 to clients
7. If hook fails, entrypoint falls back to socat proxy

## Key Constraints

- Do not add comments to source code files
- Docker image must be compatible with Pterodactyl/Pelican panel conventions
- The `container` user (UID 1000) is standard for Pterodactyl
- Voice port must be allocated as a secondary port in the Pterodactyl panel
- voicefix.so MUST be compiled as 32-bit (i386) to match samp03svr
- SA:MP server is always a 32-bit Linux ELF binary

## Build and Test

```bash
cd docker
docker build -t samp:latest .
docker run -e SERVER_PORT=7777 -e VOICE_PORT=7070 -p 7777:7777/udp -p 7070:7070/udp samp:latest
```

## Deployment

1. Push to GitHub to trigger the Docker image build via GitHub Actions
2. Import `egg-samp.json` into Pterodactyl panel
3. Update the `docker_images` field in the egg with the actual GHCR path
4. Create a server, allocate primary port (game) + secondary port (voice)
5. Set the VOICE_PORT variable to match the secondary allocation
