#!/bin/bash

cd /home/container

GAME_PORT=${SERVER_PORT:-7777}
VOICE_PORT=${VOICE_PORT:-7070}
VOICE_PROXY=${VOICE_PROXY:-1}

if [ "$VOICE_PROXY" = "1" ] && [ -f "plugins/sampvoice.so" ]; then
    for d in . plugins scriptfiles; do
        mkdir -p "$d" 2>/dev/null
        printf "voice_host = 0.0.0.0\nvoice_port = %s\n" "$VOICE_PORT" > "$d/control.cfg"
        printf "voice_host = 0.0.0.0\nvoice_port = %s\n" "$VOICE_PORT" > "$d/voice.cfg"
    done
    if [ -f "server.cfg" ]; then
        sed -i '/^sv_voiceport/d' server.cfg
        printf "sv_voiceport %s\n" "$VOICE_PORT" >> server.cfg
    fi
fi

if [ "$VOICE_PROXY" != "1" ]; then
    exec env LD_LIBRARY_PATH=./plugins:. ./samp03svr
fi

BEFORE=$(ss -uln 2>/dev/null | awk '{print $5}' | grep -o '[0-9]*$' | sort -un)

LD_LIBRARY_PATH=./plugins:. ./samp03svr &
SAMP_PID=$!

VOICE_DETECTED=""
for i in $(seq 1 15); do
    sleep 2
    if ! kill -0 "$SAMP_PID" 2>/dev/null; then
        wait $SAMP_PID
        exit $?
    fi
    AFTER=$(ss -uln 2>/dev/null | awk '{print $5}' | grep -o '[0-9]*$' | sort -un)
    for port in $(comm -13 <(echo "$BEFORE") <(echo "$AFTER")); do
        if [ "$port" != "$GAME_PORT" ] && [ "$port" != "$VOICE_PORT" ] && [ "$port" -gt 1024 ] 2>/dev/null; then
            VOICE_DETECTED=$port
            break 2
        fi
    done
done

if [ -n "$VOICE_DETECTED" ] && [ "$VOICE_DETECTED" != "$VOICE_PORT" ]; then
    if ! ss -uln 2>/dev/null | grep -q ":${VOICE_PORT} "; then
        socat UDP4-LISTEN:${VOICE_PORT},fork,reuseaddr UDP4:127.0.0.1:${VOICE_DETECTED} &
        echo "[VoiceProxy] Forwarding UDP :${VOICE_PORT} -> :${VOICE_DETECTED}"
    else
        echo "[VoiceProxy] Voice server on correct port ${VOICE_PORT}"
    fi
elif [ -z "$VOICE_DETECTED" ]; then
    echo "[VoiceProxy] No voice server detected, proxy not needed"
else
    echo "[VoiceProxy] Voice server on correct port ${VOICE_PORT}"
fi

wait $SAMP_PID
