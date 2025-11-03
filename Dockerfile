FROM ghcr.io/cirruslabs/flutter:stable

WORKDIR /app

# Copy pubspec first for better layer caching
COPY pubspec.yaml ./
COPY analysis_options.yaml ./
RUN flutter pub get || true

# Copy the rest of the source
COPY . .

# Fetch dependencies and build the Android release APK
RUN flutter pub get \
 && flutter build apk --release

# Expose build artifacts for Coolify to make available as downloads
RUN mkdir -p /artifacts \
 && cp -v build/app/outputs/flutter-apk/app-release.apk /artifacts/

# Not a running service; container exits after build
CMD ["/bin/bash", "-lc", "ls -lh /artifacts && echo 'Build complete' && exit 0"]
