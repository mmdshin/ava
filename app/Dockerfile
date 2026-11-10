# Builds the nurses' app and the admin panel for the web and serves
# both with nginx: app on :8000, admin panel on :8001.
#
#   docker build --build-arg AVA_API_URL=https://api.example.com -t ava-web .
#
# FLUTTER_VERSION: keep it equal to your `flutter --version`.
ARG FLUTTER_VERSION=3.35.7

FROM ghcr.io/cirruslabs/flutter:${FLUTTER_VERSION} AS build
WORKDIR /src
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
ARG AVA_API_URL=http://localhost:8080
RUN flutter build web --release --dart-define=AVA_API_URL=${AVA_API_URL} -o /out/app \
 && flutter build web --release -t lib/main_admin.dart --dart-define=AVA_API_URL=${AVA_API_URL} -o /out/admin

FROM nginx:1.27-alpine
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /out/app /usr/share/nginx/html/app
COPY --from=build /out/admin /usr/share/nginx/html/admin
EXPOSE 8000 8001
