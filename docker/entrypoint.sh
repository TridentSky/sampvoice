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
    if [ -f "server.cfg" ]; then
        sed -i '/^sv_voiceport/d' server.cfg
        printf "sv_voiceport %s\n" "$VOICE_PORT" >> server.cfg
        if ! grep -q 'sampvoice' server.cfg 2>/dev/null; then
            if grep -q '^plugins' server.cfg; then
                sed -i 's/^plugins\s*\(.*\)/plugins \1 sampvoice/' server.cfg
            else
                printf "plugins sampvoice\n" >> server.cfg
            fi
            printf "\033[1;33m[Startup]\033[0m Added sampvoice to server.cfg plugins line\n"
        fi
    fi
    printf "\033[1m[Startup]\033[0m Voice config applied (sv_voiceport %s)\n" "$VOICE_PORT"
    printf "\033[1;36m[Startup]\033[0m sampvoice.so check:\n"
    file plugins/sampvoice.so 2>&1 | sed 's/^/  /'
    ldd plugins/sampvoice.so 2>&1 | grep -i 'not found' | sed 's/^/  /'
fi

if [ "$VOICE_PROXY" != "1" ]; then
    printf "\033[1m[Startup]\033[0m Starting SA-MP server\n"
    exec env LD_LIBRARY_PATH=./plugins:. ./samp03svr
fi

printf "\033[1m[Startup]\033[0m Starting SA-MP server with voice hook\n"

HOOK_ACTIVE=0
if [ -f "/usr/lib/voicefix.so" ] && [ -f "/etc/ld.so.preload" ]; then
    export SV_VOICE_PORT="$VOICE_PORT"
    HOOK_ACTIVE=1
    printf "\033[1;36m[VoiceHook] /etc/ld.so.preload active: forcing voice bind to :%s\033[0m\n" "$VOICE_PORT"
else
    printf "\033[1;33m[VoiceHook] voicefix.so not found, falling back to socat proxy\033[0m\n"
fi

> /tmp/samp.log
LD_LIBRARY_PATH=./plugins:. ./samp03svr >> /tmp/samp.log 2>&1 &
SAMP_PID=$!
sleep 3
if [ "$HOOK_ACTIVE" = "1" ]; then
    if grep -q 'VoiceHook.*loaded' /tmp/samp.log 2>/dev/null; then
        printf "\033[1;32m[VoiceHook] Hook loaded successfully\033[0m\n"
    else
        printf "\033[1;31m[VoiceHook] Hook may not have loaded. First 5 lines:\033[0m\n"
        head -5 /tmp/samp.log 2>/dev/null | sed 's/^/  /'
    fi
fi
tail -f /tmp/samp.log &
TAIL_PID=$!

ACTIVE_PORT=""
SOCAT_PIDS=""
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

    ACTIVE_PORT="$LATEST"

    if [ "$LATEST" = "$VOICE_PORT" ]; then
        printf "\033[1;32m[VoiceProxy] Voice bound to :%s (direct, no proxy needed)\033[0m\n" "$LATEST"
    else
        printf "\033[1;33m[VoiceProxy] Voice on :%s, starting proxy to :%s\033[0m\n" "$LATEST" "$VOICE_PORT"
        if [ -n "$SOCAT_PIDS" ]; then
            kill $SOCAT_PIDS 2>/dev/null
            wait $SOCAT_PIDS 2>/dev/null
        fi
        socat UDP4-LISTEN:${VOICE_PORT},fork,reuseaddr UDP4:127.0.0.1:${LATEST} &
        PID1=$!
        socat TCP4-LISTEN:${VOICE_PORT},fork,reuseaddr TCP4:127.0.0.1:${LATEST} &
        PID2=$!
        SOCAT_PIDS="$PID1 $PID2"
        printf "\033[1;32m[VoiceProxy] Forwarding :%s -> :%s (TCP+UDP)\033[0m\n" "$VOICE_PORT" "$LATEST"
    fi

    printf "\033[1;36m[VoiceProxy] ---- Status ----\033[0m\n"
    printf "\033[1;36m[VoiceProxy]   External: :%s\033[0m\n" "$VOICE_PORT"
    printf "\033[1;36m[VoiceProxy]   Internal: :%s\033[0m\n" "$ACTIVE_PORT"
    printf "\033[1;36m[VoiceProxy] ----------------\033[0m\n"
done

kill $TAIL_PID $SOCAT_PIDS 2>/dev/null
