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

ACTIVE_PORT=""
SOCAT_PIDS=""
SEEN_PORTS=""
LOG_LINES=0

printf "\033[1;36m[VoiceProxy] Monitoring voice ports...\033[0m\n"

while kill -0 "$SAMP_PID" 2>/dev/null; do
    sleep 2

    TOTAL=$(wc -l < /tmp/samp.log 2>/dev/null || echo 0)
    [ "$TOTAL" -eq "$LOG_LINES" ] && continue

    LATEST=$(tail -n +"$((LOG_LINES + 1))" /tmp/samp.log 2>/dev/null | grep -o 'voice server running on port [0-9]*' | grep -o '[0-9]*$' | tail -1)
    LOG_LINES=$TOTAL

    [ -z "$LATEST" ] && continue
    [ "$LATEST" = "$ACTIVE_PORT" ] && continue

    if ! echo "$SEEN_PORTS" | grep -q ":${LATEST}:"; then
        SEEN_PORTS="${SEEN_PORTS}:${LATEST}:"
    fi

    if [ -n "$SOCAT_PIDS" ]; then
        kill $SOCAT_PIDS 2>/dev/null
        wait $SOCAT_PIDS 2>/dev/null
        SOCAT_PIDS=""
        printf "\033[1;33m[VoiceProxy] Port change: :%s -> :%s\033[0m\n" "$ACTIVE_PORT" "$LATEST"
    fi

    if [ "$LATEST" = "$VOICE_PORT" ]; then
        ACTIVE_PORT="$LATEST"
        printf "\033[1;32m[VoiceProxy] Voice on port %s (direct, no proxy needed)\033[0m\n" "$LATEST"
    else
        socat UDP4-LISTEN:${VOICE_PORT},fork,reuseaddr UDP4:127.0.0.1:${LATEST} &
        PID1=$!
        socat TCP4-LISTEN:${VOICE_PORT},fork,reuseaddr TCP4:127.0.0.1:${LATEST} &
        PID2=$!
        SOCAT_PIDS="$PID1 $PID2"
        ACTIVE_PORT="$LATEST"
        printf "\033[1;32m[VoiceProxy] Forwarding :%s -> :%s (TCP+UDP)\033[0m\n" "$VOICE_PORT" "$LATEST"
    fi

    ALL_SEEN=$(echo "$SEEN_PORTS" | tr ':' ' ' | xargs)
    printf "\033[1;36m[VoiceProxy] ---- Status ----\033[0m\n"
    printf "\033[1;36m[VoiceProxy]   External: :%s\033[0m\n" "$VOICE_PORT"
    printf "\033[1;36m[VoiceProxy]   Internal: :%s\033[0m\n" "$ACTIVE_PORT"
    printf "\033[1;36m[VoiceProxy]   History:  %s\033[0m\n" "$ALL_SEEN"
    printf "\033[1;36m[VoiceProxy] ----------------\033[0m\n"
done

kill $TAIL_PID $SOCAT_PIDS 2>/dev/null
