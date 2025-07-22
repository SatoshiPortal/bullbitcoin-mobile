# Use a base Ubuntu image
FROM --platform=linux/amd64 ubuntu:24.04

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

# Install OpenJDK 17
RUN sudo apt-get update && sudo apt-get install -y openjdk-21-jdk && sudo rm -rf /var/lib/apt/lists/*

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/home/$USER/.cargo/bin:${PATH}"

# Verify Rust installation
RUN rustc --version && cargo --version

# Set environment variables
ENV FLUTTER_HOME=/opt/flutter
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH=$FLUTTER_HOME/bin:$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools

# Install Flutter
RUN sudo git clone https://github.com/flutter/flutter.git $FLUTTER_HOME
RUN sudo sh -c "cd $FLUTTER_HOME && git checkout stable && ./bin/flutter --version"

# Set up Android SDK
RUN sudo mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    sudo wget -q https://dl.google.com/android/repository/commandlinetools-linux-8092744_latest.zip -O android-cmdline-tools.zip && \
    sudo unzip -q android-cmdline-tools.zip -d ${ANDROID_HOME}/cmdline-tools && \
    sudo mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest && \
    sudo rm android-cmdline-tools.zip

RUN sudo chown -R $USER /opt/flutter
RUN sudo chown -R $USER /opt/android-sdk

RUN flutter config --android-sdk=/opt/android-sdk

# Accept licenses and install necessary Android SDK components
RUN yes | sdkmanager --licenses
RUN sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"

# Clean up existing app directory
RUN sudo rm -rf /app

RUN sudo mkdir /app

RUN sudo chown -R $USER /app

# Clone the Bull Bitcoin mobile repository
RUN git clone --branch main https://github.com/SatoshiPortal/bullbitcoin-mobile /app

# Create device-spec.json directly in the container
RUN echo '{\
    "supportedAbis": ["armeabi-v7a", "armeabi"],\
    "supportedLocales": ["en"],\
    "screenDensity": 280,\
    "sdkVersion": 31\
}' > /app/device-spec.json

WORKDIR /app

# Setup the project
RUN make clean
RUN make deps
RUN make build-runner
RUN make l10n

# Create .env (empty values)
RUN cp .env.template .env

# Generate a fake keystore
RUN keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload -storepass android -keypass android -dname "CN=Android Debug,O=Android,C=US"

# Set up key.properties
RUN echo "storePassword=android" > /app/android/key.properties && \
    echo "keyPassword=android" >> /app/android/key.properties && \
    echo "keyAlias=upload" >> /app/android/key.properties && \
    echo "storeFile=/app/upload-keystore.jks" >> /app/android/key.properties

# Build APK with specific target platform
RUN flutter build apk --debug --target-platform android-arm64
