#!/bin/bash

cd /home/container || exit 1

GAME_PORT=${SERVER_PORT:-7777}
VOICE_PORT=${VOICE_PORT:-7070}
VOICE_PROXY=${VOICE_PROXY:-1}

printf "\033[1m[Startup]\033[0m Port: %s | Voice proxy: %s | Voice port: %s\n" "$GAME_PORT" "$VOICE_PROXY" "$VOICE_PORT"

if [ ! -f "./samp03svr" ]; then
    printf "\033[1;31m[Startup] samp03svr not found. Please reinstall the server.\033[0m\n"
    sleep 10
    exit 1
fi

chmod +x ./samp03svr 2>/dev/null
chmod +x ./announce 2>/dev/null

if [ "$VOICE_PROXY" = "1" ] && [ -f "plugins/sampvoice.so" ]; then
    for d in . plugins scriptfiles; do
        mkdir -p "$d" 2>/dev/null
        printf "voice_host = 0.0.0.0\nvoice_port = %s\n" "$VOICE_PORT" > "$d/control.cfg" 2>/dev/null
        printf "voice_host = 0.0.0.0\nvoice_port = %s\n" "$VOICE_PORT" > "$d/voice.cfg" 2>/dev/null
    done
    if [ -f "server.cfg" ]; then
        sed -i '/^sv_voiceport/d' server.cfg
        printf "sv_voiceport %s\n" "$VOICE_PORT" >> server.cfg
    fi
    printf "\033[1m[Startup]\033[0m Voice config applied\n"
fi

if [ "$VOICE_PROXY" != "1" ]; then
    printf "\033[1m[Startup]\033[0m Starting SA-MP server\n"
    exec env LD_LIBRARY_PATH=./plugins:. ./samp03svr
fi

printf "\033[1m[Startup]\033[0m Starting SA-MP server with voice proxy\n"

> /tmp/samp.log
LD_LIBRARY_PATH=./plugins:. ./samp03svr >> /tmp/samp.log 2>&1 &
SAMP_PID=$!
tail -f /tmp/samp.log &
TAIL_PID=$!

DETECTED=""
for _ in $(seq 1 30); do
    sleep 1
    if ! kill -0 "$SAMP_PID" 2>/dev/null; then
        break
    fi
    DETECTED=$(grep -o 'voice server running on port [0-9]*' /tmp/samp.log 2>/dev/null | grep -o '[0-9]*$' | tail -1)
    [ -n "$DETECTED" ] && break
done

if [ -n "$DETECTED" ] && [ "$DETECTED" != "$VOICE_PORT" ]; then
    socat UDP4-LISTEN:${VOICE_PORT},fork,reuseaddr UDP4:127.0.0.1:${DETECTED} &
    socat TCP4-LISTEN:${VOICE_PORT},fork,reuseaddr TCP4:127.0.0.1:${DETECTED} &
    printf "\033[1;32m[VoiceProxy] Forwarding :%s -> :%s (TCP+UDP)\033[0m\n" "$VOICE_PORT" "$DETECTED"
elif [ "$DETECTED" = "$VOICE_PORT" ]; then
    printf "\033[1;32m[VoiceProxy] Voice on port %s\033[0m\n" "$VOICE_PORT"
else
    printf "\033[1;33m[VoiceProxy] No voice port detected in server output\033[0m\n"
fi

wait $SAMP_PID
kill $TAIL_PID 2>/dev/null
