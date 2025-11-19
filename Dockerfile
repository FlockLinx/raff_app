FROM elixir:1.18-alpine

RUN apk add --no-cache build-base

WORKDIR /app

COPY . .

RUN mix local.hex --force && \
    mix local.rebar --force

RUN mix deps.get
RUN mix compile
RUN mix release

EXPOSE 4000

CMD ["mix", "run", "--no-halt"]

