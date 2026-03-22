FROM ubuntu:22.04

RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        lib32gcc-s1 \
        libc6:i386 \
        libstdc++6:i386 \
        socat \
        iproute2 \
        curl \
        tar \
        ca-certificates && \
    (apt-get install -y --no-install-recommends libmysqlclient21:i386 || \
     apt-get install -y --no-install-recommends libmariadb3:i386 || true) && \
    rm -rf /var/lib/apt/lists/*

RUN useradd -m -d /home/container -u 1000 -s /bin/bash container

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

CMD ["/bin/bash", "/entrypoint.sh"]
