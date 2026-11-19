FROM dart:3.13.5 AS build
WORKDIR /workspace
COPY <<EOF pubspec.yaml
name: terenzo_server_image
environment:
  sdk: ^3.13.0
workspace:
  - packages/domain
  - packages/contract
  - packages/mapping
  - apps/server
EOF
COPY pubspec.lock ./
COPY packages/domain packages/domain
COPY packages/contract packages/contract
COPY packages/mapping packages/mapping
COPY apps/server apps/server
RUN dart pub get
RUN dart compile exe apps/server/bin/server.dart -o /server

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /usr/share/zoneinfo/Europe/Belgrade /usr/share/zoneinfo/Europe/Belgrade
COPY --from=build /server /app/server
WORKDIR /app
ENV HOST=0.0.0.0
ENV TZ=Europe/Belgrade
USER 65532:65532
EXPOSE 8080
CMD ["/app/server"]
