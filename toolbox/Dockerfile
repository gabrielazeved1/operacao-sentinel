FROM alpine:3.20
RUN apk add --no-cache bash curl jq bind-tools iproute2 iputils tcpdump coreutils
COPY scripts /opt/sentinel
WORKDIR /opt/sentinel
CMD ["sleep", "infinity"]
