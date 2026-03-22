# SA-MP Docker Image for Pterodactyl

Custom Docker image for SA-MP 0.3.7 servers on Pterodactyl/Pelican panels with built-in UDP voice proxy for SampVoice.

## The Problem

SampVoice picks a random UDP port for voice traffic. In containerized environments, only panel-allocated ports are exposed — random ports are unreachable from outside.

## The Solution

The Docker entrypoint automatically:
1. Writes SampVoice config files with the panel-assigned voice port
2. Starts the SA-MP server
3. Detects if the voice server bound to a different port
4. Proxies the assigned port to the internal port using `socat`

No plugin modifications needed. Works with any SampVoice version.

## Docker Image

```
ghcr.io/tridentsky/samp:latest
```

## Quick Start

1. Import `egg-samp.json` into your Pterodactyl panel
2. Create a server with a primary port (game) and secondary port (voice)
3. Set `VOICE_PORT` to match the secondary allocation
4. Start the server

## Server Variables

| Variable | Default | Description |
|---|---|---|
| `VOICE_PROXY` | `1` | Enable/disable voice proxy (1/0) |
| `VOICE_PORT` | `7070` | UDP voice port (must match panel allocation) |
| `SAMPVOICE_URL` | `none` | URL to download SampVoice plugin |
| `INSTALL_MYSQL` | `0` | Auto-install MySQL plugin (1/0) |
| `SERVER_NAME` | `My SA-MP Server` | Server name |
| `RCON_PASS` | `changeme` | RCON password |
| `MAX_PLAYERS` | `50` | Max players |

## Architecture

```
Player connects to voice port (7070)
        |
        v
  socat UDP proxy (if needed)
        |
        v
  SampVoice internal port (random)
        |
        v
  Voice server process
```

## Building

```bash
cd docker
docker build -t samp:latest .
```

Push to GHCR happens automatically via GitHub Actions on changes to `docker/`.

## Credits

Built with [Claude Code](https://claude.ai/code) by Anthropic.

## License

MIT
