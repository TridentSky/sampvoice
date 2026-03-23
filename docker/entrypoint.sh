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

get_all_ports() {
    ss -tuln 2>/dev/null | awk 'NR>1 {n=split($5,a,":"); if(a[n]+0>0) print a[n]}' | sort -un
}

BEFORE=$(get_all_ports)

LD_LIBRARY_PATH=./plugins:. ./samp03svr &
SAMP_PID=$!

sleep 3

if ! kill -0 "$SAMP_PID" 2>/dev/null; then
    printf "\033[1;31m[Startup] SA-MP server failed to start\033[0m\n"
    wait $SAMP_PID 2>/dev/null
    exit $?
fi

DETECTED=""
for _ in $(seq 1 12); do
    sleep 2
    if ! kill -0 "$SAMP_PID" 2>/dev/null; then
        wait $SAMP_PID 2>/dev/null
        exit $?
    fi
    AFTER=$(get_all_ports)
    for port in $(comm -13 <(echo "$BEFORE") <(echo "$AFTER") 2>/dev/null); do
        if [ "$port" != "$GAME_PORT" ] && [ "$port" != "$VOICE_PORT" ] && [ "$port" -gt 1024 ] 2>/dev/null; then
            DETECTED=$port
            break 2
        fi
    done
done

if [ -n "$DETECTED" ] && [ "$DETECTED" != "$VOICE_PORT" ]; then
    if ! ss -tuln 2>/dev/null | grep -q ":${VOICE_PORT} "; then
        socat UDP4-LISTEN:${VOICE_PORT},fork,reuseaddr UDP4:127.0.0.1:${DETECTED} &
        socat TCP4-LISTEN:${VOICE_PORT},fork,reuseaddr TCP4:127.0.0.1:${DETECTED} &
        printf "\033[1;32m[VoiceProxy] Forwarding :%s -> :%s (TCP+UDP)\033[0m\n" "$VOICE_PORT" "$DETECTED"
    else
        printf "\033[1;32m[VoiceProxy] Port %s already bound\033[0m\n" "$VOICE_PORT"
    fi
elif [ "$DETECTED" = "$VOICE_PORT" ]; then
    printf "\033[1;32m[VoiceProxy] Service on port %s\033[0m\n" "$VOICE_PORT"
else
    printf "\033[1;33m[VoiceProxy] No new ports detected\033[0m\n"
fi

wait $SAMP_PID
