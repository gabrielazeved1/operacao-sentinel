FROM alpine:3.20
RUN apk add --no-cache bash iproute2 tcpdump iputils curl
COPY netem.sh /usr/local/bin/netem.sh
RUN chmod +x /usr/local/bin/netem.sh
ENTRYPOINT ["/usr/local/bin/netem.sh"]
