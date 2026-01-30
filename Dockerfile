# Use a base Ubuntu image
FROM --platform=linux/amd64 ubuntu:24.04

# Build arguments
ARG VERSION=main
ARG MODE=debug
ARG FORMAT=apk
ARG SOURCE=github

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive
ENV USER="docker"

# Install necessary dependencies
RUN apt update && apt install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    wget \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

RUN apt update && apt install -y sudo
RUN adduser --disabled-password --gecos '' $USER
RUN adduser $USER sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER $USER
RUN sudo apt update

# Install OpenJDK 21
RUN sudo apt-get update && sudo apt-get install -y openjdk-21-jdk && sudo rm -rf /var/lib/apt/lists/*

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/home/$USER/.cargo/bin:${PATH}"

# Verify Rust installation
RUN rustc --version && cargo --version

# Install Android Rust targets for cross-compilation
RUN rustup target add aarch64-linux-android
RUN rustup target add armv7-linux-androideabi
RUN rustup target add x86_64-linux-android
RUN rustup target add i686-linux-android

# Set Rust flags for reproducible builds (remap absolute paths)
ENV RUSTFLAGS="--remap-path-prefix=/home/docker/.cargo=/cargo --remap-path-prefix=/app=/build"

# Set environment variables
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools

# Set up Android SDK
RUN sudo mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    sudo wget -q https://dl.google.com/android/repository/commandlinetools-linux-8092744_latest.zip -O android-cmdline-tools.zip && \
    sudo unzip -q android-cmdline-tools.zip -d ${ANDROID_HOME}/cmdline-tools && \
    sudo mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest && \
    sudo rm android-cmdline-tools.zip

RUN sudo chown -R $USER /opt/android-sdk

# Accept licenses and install necessary Android SDK components
RUN yes | sdkmanager --licenses
RUN sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"

# Install FVM (Flutter Version Manager)
RUN cd /home/$USER && curl -fsSL https://fvm.app/install.sh | bash
ENV PATH="/home/$USER/fvm/bin:/home/$USER/.pub-cache/bin:${PATH}"

# Clean up existing app directory
RUN sudo rm -rf /app

RUN sudo mkdir /app

RUN sudo chown -R $USER /app

# Get source code (clone from GitHub or copy local files)
COPY --chown=$USER:$USER . /app/local-source/
RUN if [ "$SOURCE" = "local" ]; then \
        cp -r /app/local-source/. /app/ && rm -rf /app/local-source; \
    else \
        rm -rf /app/local-source && \
        git clone --branch ${VERSION} https://github.com/SatoshiPortal/bullbitcoin-mobile /app; \
    fi

WORKDIR /app

# Install Flutter version specified in .fvmrc
RUN fvm install

# Setup the project
RUN fvm flutter clean
RUN fvm flutter pub get
RUN fvm dart run build_runner build --delete-conflicting-outputs
RUN fvm flutter gen-l10n

# Create .env (empty values)
RUN cp .env.template .env

# Generate a fake keystore
RUN keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload -storepass android -keypass android -dname "CN=Android Debug,O=Android,C=US"

# Set up key.properties
RUN echo "storePassword=android" > /app/android/key.properties && \
    echo "keyPassword=android" >> /app/android/key.properties && \
    echo "keyAlias=upload" >> /app/android/key.properties && \
    echo "storeFile=/app/upload-keystore.jks" >> /app/android/key.properties

# Build the app
RUN if [ "$FORMAT" = "aab" ]; then \
        fvm flutter build appbundle --${MODE}; \
    else \
        fvm flutter build apk --${MODE}; \
    fi
