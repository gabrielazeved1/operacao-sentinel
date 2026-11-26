FROM rust:1.88-slim-bookworm AS build
WORKDIR /src

COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo 'fn main() {}' > src/main.rs \
 && cargo build --release --locked \
 && rm -rf src target/release/sentinel-node-actix target/release/deps/sentinel_node_actix*

COPY src ./src
RUN cargo build --release --locked

FROM debian:bookworm-slim
RUN useradd --system --uid 10001 --no-create-home sentinel
COPY --from=build /src/target/release/sentinel-node-actix /usr/local/bin/sentinel-node-actix
USER sentinel
ENV NODE_NAME=node PORT=8080 WARMUP_SECONDS=3
EXPOSE 8080
HEALTHCHECK --interval=5s --timeout=3s --start-period=3s --retries=3 \
  CMD ["/usr/local/bin/sentinel-node-actix", "--healthcheck"]
ENTRYPOINT ["/usr/local/bin/sentinel-node-actix"]
