# syntax=docker/dockerfile:1.3

ARG ALPINE_VERSION="3.14.2"
ARG ERLANG_OTP_VERSION="24.1.2"
ARG ELIXIR_VERSION="1.12.3"

## release builder image

# https://github.com/hexpm/bob#docker-images
FROM "hexpm/elixir:${ELIXIR_VERSION}-erlang-${ERLANG_OTP_VERSION}-alpine-${ALPINE_VERSION}" as builder

ARG MIX_ENV=prod

RUN apk --no-cache upgrade \
    && apk --no-cache add \
        build-base \
        cargo \
        nodejs \
        npm \
        rust \
    && mix local.rebar --force \
    && mix local.hex --force

COPY mix.exs mix.lock /opt/app/

WORKDIR /opt/app

RUN mix do deps.get --only prod, deps.compile

COPY assets /opt/app/assets/

WORKDIR /opt/app/assets
RUN npm install && npm run deploy

COPY config/ /opt/app/config/
COPY lib/ /opt/app/lib/
COPY native/ /opt/app/native/
COPY priv/ /opt/app/priv/
COPY rel/ /opt/app/rel/

WORKDIR /opt/app

# recompile sentry with our source code
RUN mix phx.digest && mix deps.compile sentry --force

# temporary workaround to make rustler work with OTP 24
ENV RUSTLER_NIF_VERSION="2.15"

RUN mix release

## target image

FROM "alpine:${ALPINE_VERSION}"

RUN apk add --no-cache \
    bash \
    ca-certificates \
    librsvg \
    libstdc++ \
    pngquant \
    tini \
    ttf-dejavu

WORKDIR /opt/app

COPY --from=builder /opt/app/_build/prod/rel/asciinema .
RUN chgrp -R 0 /opt/app && chmod -R g=u /opt/app
COPY .iex.exs .

ENV PORT=4000
ENV DATABASE_URL="postgresql://postgres@postgres/postgres"
ENV RSVG_FONT_FAMILY="Dejavu Sans Mono"
ENV PATH="/opt/app/bin:${PATH}"

VOLUME ["/opt/app/uploads", "/opt/app/cache"]

EXPOSE "${PORT}"

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/opt/app/bin/asciinema", "start"]

# vim:ft=dockerfile
