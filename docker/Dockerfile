FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y \
        lib32gcc-s1 \
        libc6:i386 \
        libstdc++6:i386 \
        socat \
        iproute2 \
        curl \
        tar \
        ca-certificates && \
    apt-get install -y libmysqlclient21:i386 2>/dev/null || \
    apt-get install -y libmariadb3:i386 2>/dev/null || true && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN useradd -d /home/container -m container

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && sed -i 's/\r$//' /entrypoint.sh

USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container
