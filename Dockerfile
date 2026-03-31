# Notes about reproducibility:
# - Rust: install script is unpinned (https://sh.rustup.rs). Pin with --default-toolchain <version>.
# - FVM: install script is unpinned (https://fvm.app/install.sh). Pin by downloading a versioned binary.
# - Ubuntu base image: pinned to 24.04 tag but not a digest. apt packages can drift. Pin with ubuntu:24.04@sha256:...
# - Android cmdline-tools: pinned by build number in the URL. Safe.
# - Flutter: pinned via .fvmrc in the repo. Safe.

FROM --platform=linux/amd64 ubuntu:24.04

# Build arguments
# MODE: flutter build mode: debug or release
ARG MODE=debug
# FORMAT: output format: apk or aab
ARG FORMAT=apk
# GRADLE_HEAP: JVM heap size for Gradle (e.g. 2g, 4g, 6g)
ARG GRADLE_HEAP=4g
# ENV_SOURCE: where to get .env: template (copy from .env.template) or local (use .env from source)
ARG ENV_SOURCE=template
# FAKE_KEYSTORE: if true, generates a fake keystore for reproducibility testing
#                if false, expects real keystore and key.properties via secret mounts
ARG FAKE_KEYSTORE=true

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive
ENV APP_USER="docker"
ENV HOME="/home/$APP_USER"
ENV ANDROID_HOME=/opt/android-sdk
# Rust, FVM, pub-cache, Android SDK tools
ENV PATH="$HOME/.cargo/bin:$HOME/fvm/bin:$HOME/.pub-cache/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

# git: cloning the source repo when SOURCE=github
# unzip: extracting Android SDK zip
# xz-utils: extracting Flutter tar.xz archives
# libglu1-mesa: OpenGL library required by Android build tools
# curl: downloading Rust, Android SDK, FVM
# clang, cmake, ninja-build: toolchain for compiling native Flutter/Rust code
# pkg-config: locates system libraries during native compilation
# libgtk-3-dev: GTK headers required by Flutter toolchain
# openjdk-21-jdk: required by Gradle and Android build tools
RUN apt-get update && apt-get install -y \
    git \
    unzip \
    xz-utils \
    libglu1-mesa \
    curl \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    openjdk-21-jdk \
    && rm -rf /var/lib/apt/lists/*

RUN adduser --disabled-password --gecos '' $APP_USER && \
    mkdir -p /opt/android-sdk /app && \
    chown -R $APP_USER /opt/android-sdk /app

USER $APP_USER

# Install Rust
RUN curl -sSf https://sh.rustup.rs | sh -s -- -y && \
    rustc --version && cargo --version && \
    rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android

# Set up Android SDK
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    curl -o /tmp/android-cmdline-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-8092744_latest.zip && \
    unzip -q /tmp/android-cmdline-tools.zip -d ${ANDROID_HOME}/cmdline-tools && \
    mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest && \
    rm /tmp/android-cmdline-tools.zip && \
    yes | sdkmanager --licenses && \
    sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"

# Install FVM (Flutter Version Manager)
RUN curl -fsSL https://fvm.app/install.sh | bash

COPY --chown=$APP_USER:$APP_USER . /app/

WORKDIR /app

# Install Flutter version specified in .fvmrc
RUN fvm install

# Setup the project
RUN fvm flutter pub get
RUN fvm dart run build_runner build --delete-conflicting-outputs
RUN fvm flutter gen-l10n

# Use .env.template unless ENV_SOURCE=local, in which case .env is already present
RUN if [ "$ENV_SOURCE" != "local" ]; then \
        cp .env.template .env; \
    fi

# For production: mount a real keystore and key.properties via:
#   docker build --secret id=keystore,src=./upload-keystore.jks \
#                --secret id=key_properties,src=./android/key.properties
RUN --mount=type=secret,id=keystore \
    --mount=type=secret,id=key_properties \
    if [ "$FAKE_KEYSTORE" = "true" ]; then \
        keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload -storepass android -keypass android -dname "CN=Android Debug,O=Android,C=US" && \
        echo "storePassword=android" > /app/android/key.properties && \
        echo "keyPassword=android" >> /app/android/key.properties && \
        echo "keyAlias=upload" >> /app/android/key.properties && \
        echo "storeFile=/app/upload-keystore.jks" >> /app/android/key.properties; \
    else \
        cp /run/secrets/keystore /app/upload-keystore.jks && \
        cp /run/secrets/key_properties /app/android/key.properties; \
    fi

# Configure Gradle for containerized builds
RUN mkdir -p $HOME/.gradle && \
    echo "org.gradle.daemon=false" > $HOME/.gradle/gradle.properties && \
    echo "org.gradle.jvmargs=-Xmx${GRADLE_HEAP} -XX:+HeapDumpOnOutOfMemoryError" >> $HOME/.gradle/gradle.properties

# Build the app
# SOURCE_DATE_EPOCH: makes OpenSSL use a deterministic build timestamp instead of wall-clock time
# CARGO_ENCODED_RUSTFLAGS: remaps absolute paths so they don't differ between machines
RUN SOURCE_DATE_EPOCH=$(git -C /app log -1 --format=%ct) && \
    CARGO_ENCODED_RUSTFLAGS=$(printf '%s\037%s\037%s' \
        "--remap-path-prefix=$HOME/.cargo=/cargo" \
        "--remap-path-prefix=$HOME/.rustup=/rustup" \
        "--remap-path-prefix=/app=/build") && \
    export SOURCE_DATE_EPOCH CARGO_ENCODED_RUSTFLAGS && \
    if [ "$FORMAT" = "aab" ]; then \
        fvm flutter build appbundle --${MODE}; \
    else \
        fvm flutter build apk --${MODE}; \
    fi
