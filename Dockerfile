FROM --platform=linux/amd64 debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

ARG USERNAME="bull"
ENV USER=$USERNAME
ARG FVM_VERSION=4.0.5
ARG FLUTTER_VERSION=3.38.5
ARG ANDROID_CMDLINE_TOOLS_VERSION=14742923

# Android versions (passed via --build-arg from Makefile, defaults as fallback)
ARG JVM_TARGET=21
ARG ANDROID_API_LEVEL=36
ARG ANDROID_BUILD_TOOLS=36.0.0
ARG ANDROID_NDK=29.0.14206865
ARG RUST_VERSION=1.95.0


ENV ANDROID_HOME=/opt/android-sdk
ENV PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools

# Install dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    make \
    openjdk-${JVM_TARGET}-jdk-headless \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Reproducibility / release tooling
# Installed as root so they land in /usr/local/bin before we drop privileges.

ARG APKTOOL_VERSION=3.0.1
ARG APKTOOL_SHA256=b947b945b4bc455609ba768d071b64d9e63834079898dbaae15b67bf03bcd362
ARG BUNDLETOOL_VERSION=1.18.3
ARG BUNDLETOOL_SHA256=a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29

RUN curl -fsSL \
        https://github.com/iBotPeaches/Apktool/releases/download/v${APKTOOL_VERSION}/apktool_${APKTOOL_VERSION}.jar \
        -o /usr/local/bin/apktool.jar \
    && echo "${APKTOOL_SHA256}  /usr/local/bin/apktool.jar" | sha256sum -c - \
    && printf '#!/bin/sh\nexec java -jar /usr/local/bin/apktool.jar "$@"\n' \
        > /usr/local/bin/apktool \
    && chmod +x /usr/local/bin/apktool

RUN curl -fsSL \
        https://github.com/google/bundletool/releases/download/${BUNDLETOOL_VERSION}/bundletool-all-${BUNDLETOOL_VERSION}.jar \
        -o /usr/local/bin/bundletool.jar \
    && echo "${BUNDLETOOL_SHA256}  /usr/local/bin/bundletool.jar" | sha256sum -c - \
    && printf '#!/bin/sh\nexec java -jar /usr/local/bin/bundletool.jar "$@"\n' \
        > /usr/local/bin/bundletool \
    && chmod +x /usr/local/bin/bundletool

# Create user and pre-chown toolchain dirs, then drop privileges for good.
# Pin UID/GID to 1000 so the makefile's --userns=keep-id:uid=1000,gid=1000
# maps the host user onto `bull` regardless of what UID the host user has.
RUN adduser --uid 1000 --disabled-password --gecos '' $USER \
    && mkdir -p $ANDROID_HOME \
    && chown -R $USER $ANDROID_HOME

USER $USER
WORKDIR /home/$USER

# Install Rust (pinned for reproducible builds; cargokit defaults to 'stable' for
# plugins without cargokit.yaml, so this version determines their output)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --default-toolchain ${RUST_VERSION}
ENV PATH="/home/$USER/.cargo/bin:${PATH}"

# Add Android Rust targets
RUN rustup target add aarch64-linux-android
RUN rustup target add armv7-linux-androideabi
RUN rustup target add x86_64-linux-android
RUN rustup target add i686-linux-android
RUN rustc --version && cargo --version

# Install FVM
RUN curl -fsSL https://fvm.app/install.sh -o /tmp/fvm-install.sh
RUN bash /tmp/fvm-install.sh ${FVM_VERSION}
RUN rm /tmp/fvm-install.sh
ENV PATH="/home/$USER/fvm/bin:${PATH}"

# Install Flutter via FVM
RUN fvm install ${FLUTTER_VERSION}
RUN fvm global ${FLUTTER_VERSION}
ENV PATH="/home/$USER/fvm/default/bin:${PATH}"

# Set up Android SDK
RUN curl -fsSL https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip -o /tmp/android-cmdline-tools.zip
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools
RUN unzip -q /tmp/android-cmdline-tools.zip -d ${ANDROID_HOME}/cmdline-tools
RUN mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest
RUN rm /tmp/android-cmdline-tools.zip

# Install Android SDK components
RUN yes | sdkmanager --sdk_root=${ANDROID_HOME} --licenses
RUN sdkmanager --sdk_root=${ANDROID_HOME} "platform-tools"
RUN sdkmanager --sdk_root=${ANDROID_HOME} "platforms;android-${ANDROID_API_LEVEL}"
RUN sdkmanager --sdk_root=${ANDROID_HOME} "build-tools;${ANDROID_BUILD_TOOLS}"
RUN sdkmanager --sdk_root=${ANDROID_HOME} "ndk;${ANDROID_NDK}"

# Pre-download Flutter artifacts (Dart SDK, sky_engine, flutter_patched_sdk,
# Gradle wrapper, Material fonts, Android build-tools glue) so the first
# `flutter pub get` / `flutter build` inside the container doesn't hit the network.
RUN fvm flutter precache --android --universal \
    --no-ios --no-linux --no-macos --no-windows --no-fuchsia --no-web
