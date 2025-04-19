# Build hardware proxy
FROM rust:1.74 AS proxy-builder

RUN apt-get update && apt-get install -y libudev-dev pkg-config && rm -rf /var/lib/apt/lists/*
WORKDIR /usr/src/sms-proxy
COPY Cargo.toml Cargo.lock ./
COPY src ./src
RUN cargo build --release

# Build device plugin
FROM golang:1.21 AS plugin-builder

WORKDIR /go/src/modem-plugin
COPY modem_plugin.go .
RUN go mod init modem-plugin && go build -o modem-plugin

# Final image
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y libudev0 ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=proxy-builder /usr/src/sms-proxy/target/release/sms-proxy /usr/local/bin/sms-proxy
COPY --from=plugin-builder /go/src/modem-plugin/modem-plugin /opt/nomad/plugins/modem-plugin
COPY config.toml /etc/sms-proxy/config.toml

EXPOSE 8080 9090
CMD ["/usr/local/bin/sms-proxy"]
