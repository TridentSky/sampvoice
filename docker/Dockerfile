FROM ghcr.io/parkervcp/games:samp

USER root

RUN apt-get update && \
    apt-get install -y socat iproute2 && \
    apt-get install -y libmysqlclient21:i386 2>/dev/null || \
    apt-get install -y libmariadb3:i386 2>/dev/null || true && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && sed -i 's/\r$//' /entrypoint.sh

USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container
