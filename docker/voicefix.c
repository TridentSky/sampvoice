#define _GNU_SOURCE
#include <dlfcn.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

static int (*real_bind)(int, const struct sockaddr *, socklen_t) = NULL;

int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen) {
    if (!real_bind)
        real_bind = dlsym(RTLD_NEXT, "bind");

    if (addr && addr->sa_family == AF_INET && addrlen >= sizeof(struct sockaddr_in)) {
        struct sockaddr_in *sin = (struct sockaddr_in *)addr;

        int type;
        socklen_t type_len = sizeof(type);
        if (getsockopt(sockfd, SOL_SOCKET, SO_TYPE, &type, &type_len) == 0 && type == SOCK_DGRAM) {
            if (sin->sin_port == 0 && sin->sin_addr.s_addr == INADDR_ANY) {
                const char *port_str = getenv("SV_VOICE_PORT");
                if (port_str) {
                    int port = atoi(port_str);
                    if (port > 0 && port < 65536) {
                        struct sockaddr_in modified;
                        memcpy(&modified, sin, sizeof(modified));
                        modified.sin_port = htons(port);
                        int ret = real_bind(sockfd, (struct sockaddr *)&modified, addrlen);
                        if (ret == 0) {
                            fprintf(stderr, "[VoiceHook] Bound UDP to port %d\n", port);
                            unsetenv("SV_VOICE_PORT");
                            return 0;
                        }
                    }
                }
            }
        }
    }

    return real_bind(sockfd, addr, addrlen);
}
