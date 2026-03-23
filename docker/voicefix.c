#define _GNU_SOURCE
#include <dlfcn.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

__attribute__((constructor))
static void voicefix_init(void) {
    if (getenv("SV_VOICE_PORT"))
        fprintf(stderr, "[VoiceHook] voicefix.so loaded (pid=%d)\n", getpid());
}

int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen) {
    int (*real_bind)(int, const struct sockaddr *, socklen_t);
    real_bind = (int (*)(int, const struct sockaddr *, socklen_t))dlsym(RTLD_NEXT, "bind");
    if (!real_bind)
        return -1;

    if (addr && addr->sa_family == AF_INET && addrlen >= sizeof(struct sockaddr_in)) {
        const struct sockaddr_in *sin = (const struct sockaddr_in *)addr;

        if (sin->sin_port == 0) {
            int type = 0;
            socklen_t type_len = sizeof(type);
            if (getsockopt(sockfd, SOL_SOCKET, SO_TYPE, &type, &type_len) == 0 && type == SOCK_DGRAM) {
                const char *port_str = getenv("SV_VOICE_PORT");
                if (port_str && port_str[0] != '\0') {
                    int port = atoi(port_str);
                    if (port > 0 && port < 65536) {
                        struct sockaddr_in modified;
                        memcpy(&modified, sin, sizeof(modified));
                        modified.sin_port = htons((unsigned short)port);
                        int ret = real_bind(sockfd, (const struct sockaddr *)&modified, addrlen);
                        if (ret == 0) {
                            fprintf(stderr, "[VoiceHook] Bound UDP to port %d\n", port);
                            unsetenv("SV_VOICE_PORT");
                            return 0;
                        }
                        fprintf(stderr, "[VoiceHook] Failed to bind to port %d, using random\n", port);
                    }
                }
            }
        }
    }

    return real_bind(sockfd, addr, addrlen);
}
