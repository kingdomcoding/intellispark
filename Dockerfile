# ----- Stage 1: base (shared Elixir + deps) -----
ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=27.3.4.10
ARG ALPINE_VERSION=3.21.7

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION} AS base

RUN apk add --no-cache build-base git curl inotify-tools openssl linux-headers

WORKDIR /app
RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get

RUN mkdir config
COPY config/config.exs config/
COPY config/dev.exs config/
COPY config/prod.exs config/
COPY config/test.exs config/
RUN mix deps.compile

# ----- Stage 2: dev -----
FROM base AS dev

ENV MIX_ENV=dev
EXPOSE 4800
CMD ["mix", "phx.server"]

# ----- Stage 3: builder -----
FROM base AS builder

ENV MIX_ENV=prod

COPY priv priv
COPY lib lib
COPY assets assets

RUN mix assets.deploy

COPY config/runtime.exs config/
RUN mix compile
RUN mix release

# ----- Stage 4: runtime -----
FROM alpine:${ALPINE_VERSION} AS runtime

RUN apk add --no-cache libstdc++ libgcc ncurses openssl ca-certificates curl tini

ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

WORKDIR /app
RUN addgroup -S app && adduser -S -G app app && chown app:app /app

COPY --from=builder --chown=app:app /app/_build/prod/rel/intellispark ./
COPY --chown=app:app rel/overlays/bin/start.sh /app/bin/start.sh
RUN chmod +x /app/bin/start.sh

USER app
EXPOSE 4800

HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
  CMD curl -fsS http://127.0.0.1:${PORT:-4800}/healthz || exit 1

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/app/bin/start.sh"]
