# FROM rust:1.45.2-stretch AS librespot_build

# # RUN apk --no-cache add git alsa-lib-dev
# # RUN apt-get update && apt-get install -y git libasound2-dev pkg-config

# # RUN git clone https://github.com/librespot-org/librespot.git /librespot
# COPY librespot /librespot

# WORKDIR /librespot
# # RUN cargo build --release --no-default-features
# RUN cargo build --no-default-features


FROM buildpack-deps:buster AS s6_container_download

ADD https://github.com/just-containers/s6-overlay/releases/download/v2.1.0.2/s6-overlay-amd64-installer /tmp/

FROM elixir:1.10

RUN mkdir -p /usr/local/bin

# COPY --from=librespot_build /librespot/target/release/librespot /opt/local/bin/librespot
COPY --from=s6_container_download /tmp/s6-overlay-amd64-installer /tmp/s6-overlay-amd64-installer

RUN chmod a+x /tmp/s6-overlay-amd64-installer && /tmp/s6-overlay-amd64-installer /

ENTRYPOINT ["/init"]

COPY docker/files /

ARG LIBRESPOT_PIPE=/var/run/strobe/librespot
ARG LIBRESPOT_NAME="Strobe"

RUN mkdir -p "$(dirname $LIBRESPOT_PIPE)"

ENV LIBRESPOT_PIPE="${LIBRESPOT_PIPE}"
ENV LIBRESPOT_NAME="${LIBRESPOT_NAME}"
# ENV RUST_LOG=debug

RUN mkfifo "$LIBRESPOT_PIPE"

# RUN apt-get update && apt-get install -y elixir
RUN mkdir -p /strobe

RUN apt-get update && apt-get install -y apt-transport-https ca-certificates

# RUN curl -sL https://deb.nodesource.com/setup_10.x | bash -
# RUN apt-get install -y nodejs

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update && apt-get install -y yarn
RUN apt-get install -y libavahi-compat-libdnssd-dev

ARG SENTRY_DSN
ARG PAPERTRAIL_SYSTEM_HOST
ARG PAPERTRAIL_SYSTEM_NAME

ENV MIX_ENV=prod \
    PAPERTRAIL_SYSTEM_HOST="${PAPERTRAIL_SYSTEM_HOST}" \
    PAPERTRAIL_SYSTEM_NAME="${PAPERTRAIL_SYSTEM_NAME}" \
    PORT=4000 \
    SENTRY_DSN="${SENTRY_DSN}"


COPY . /strobe/

WORKDIR /strobe/apps/elvis

RUN mkdir -p /var/db/peep

RUN mix do local.hex --force, local.rebar --force, deps.get, deps.compile, compile

VOLUME ["/var/db"]

RUN yarn install && $(yarn bin)/webpack --config config/webpack.config.js -p && mix phx.digest

# put this last so changes from librespot don't trigger a full re-build
# COPY --from=librespot_build /librespot/target/debug/librespot /opt/local/bin/librespot
