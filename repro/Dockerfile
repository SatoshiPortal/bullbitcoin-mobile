# Use a base Ubuntu image
FROM ubuntu:20.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary dependencies
RUN apt-get update && apt-get install -y \
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

# Add the repository for OpenJDK 17
RUN add-apt-repository ppa:openjdk-r/ppa

# Install OpenJDK 17
RUN apt-get update && apt-get install -y openjdk-17-jdk && rm -rf /var/lib/apt/lists/*

# Set up Java environment
ENV JAVA_HOME /usr/lib/jvm/java-17-openjdk-amd64
ENV PATH $JAVA_HOME/bin:$PATH

# Install bundletool
RUN wget https://github.com/google/bundletool/releases/download/1.15.5/bundletool-all-1.15.5.jar -O /usr/local/bin/bundletool.jar
RUN echo '#!/bin/sh\njava -jar /usr/local/bin/bundletool.jar "$@"' > /usr/local/bin/bundletool && chmod +x /usr/local/bin/bundletool

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Verify Rust installation
RUN rustc --version && cargo --version

# Install Flutter
ENV FLUTTER_HOME /opt/flutter
ENV PATH $FLUTTER_HOME/bin:$PATH
RUN git clone https://github.com/flutter/flutter.git $FLUTTER_HOME
RUN cd $FLUTTER_HOME && git checkout stable && ./bin/flutter --version

# Set up Android SDK
ENV ANDROID_SDK_ROOT /opt/android-sdk
ENV PATH $PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-8092744_latest.zip -O android-cmdline-tools.zip && \
    unzip -q android-cmdline-tools.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools && \
    mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest && \
    rm android-cmdline-tools.zip

# Accept licenses and install necessary Android SDK components
RUN yes | sdkmanager --licenses
RUN sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# Clean up existing app directory
RUN rm -rf /app

# Clone the Bull Bitcoin mobile repository
RUN git clone https://github.com/SatoshiPortal/bullbitcoin-mobile /app

# Copy device-spec.json into the container
COPY device-spec.json /app/device-spec.json

# Set up the Flutter project
WORKDIR /app
RUN flutter pub get

# Generate a fake keystore
RUN keytool -genkey -v -keystore /app/android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload -storepass android -keypass android -dname "CN=Android Debug,O=Android,C=US"

# Set up key.properties
RUN echo "storePassword=android" > /app/android/key.properties && \
    echo "keyPassword=android" >> /app/android/key.properties && \
    echo "keyAlias=upload" >> /app/android/key.properties && \
    echo "storeFile=../app/upload-keystore.jks" >> /app/android/key.properties

# Pre-build the project to download all necessary dependencies
RUN flutter precache

# Build the AAB (Android App Bundle)
RUN flutter build appbundle --release

# Generate split APKs
RUN bundletool build-apks --bundle=/app/build/app/outputs/bundle/release/app-release.aab --output=/app/app.apks --device-spec=/app/device-spec.json

# List apks
# RUN unzip -l /app/app.apks

# Extract specific APKs
RUN unzip -p /app/app.apks splits/base-master.apk > /app/base.apk && \
    unzip -p /app/app.apks splits/base-armeabi_v7a.apk > /app/armeabi_v7a.apk && \
    unzip -p /app/app.apks splits/base-en.apk > /app/en.apk && \
    unzip -p /app/app.apks splits/base-xhdpi.apk > /app/xhdpi.apk

# Clean up
RUN rm /app/app.apks

# Create the output directory
RUN mkdir -p /app/build-output/

# Output the build artifacts
CMD ["sh", "-c", "cp /app/base.apk /app/armeabi_v7a.apk /app/en.apk /app/xhdpi.apk /app/build/app/outputs/bundle/release/app-release.aab /app/build-output/"]