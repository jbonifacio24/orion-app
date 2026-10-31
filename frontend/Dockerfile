FROM debian:bookworm-slim AS build
ARG FLUTTER_VERSION=3.44.8
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" -o /tmp/flutter.tar.xz \
    && tar -xJf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz
RUN git config --global --add safe.directory /opt/flutter \
    && git config --global http.version HTTP/1.1
ENV PATH="/opt/flutter/bin:${PATH}"
WORKDIR /workspace
COPY frontend/pubspec.yaml frontend/pubspec.lock ./
RUN flutter pub get
COPY frontend/ ./
ARG API_BASE_URL
RUN flutter build web \
    --release \
    --dart-define=APP_ENV=production \
    --dart-define=API_BASE_URL=${API_BASE_URL}

FROM nginx:stable-alpine
COPY frontend/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /workspace/build/web /usr/share/nginx/html
EXPOSE 8080