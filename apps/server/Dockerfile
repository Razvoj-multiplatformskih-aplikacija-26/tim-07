FROM dart:3.13.5 AS build
WORKDIR /src

COPY pubspec.lock ./
COPY packages/ packages/
COPY apps/server/ apps/server/
RUN printf 'name: tim_07_workspace\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\nworkspace:\n' > pubspec.yaml \
 && for dir in packages/*/; do printf '  - %s\n' "${dir%/}" >> pubspec.yaml; done \
 && printf '  - apps/server\n' >> pubspec.yaml \
 && cat pubspec.yaml
RUN dart pub get
RUN dart compile exe apps/server/bin/server.dart -o /src/server

FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates tzdata curl \
 && rm -rf /var/lib/apt/lists/*

ENV TZ=Europe/Belgrade

WORKDIR /app
COPY --from=build /src/server /app/server
COPY apps/server/migrations/ /app/migrations/

USER 65532:65532
EXPOSE 8080
CMD ["/app/server"]
