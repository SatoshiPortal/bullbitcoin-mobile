# Use a base Ubuntu image
FROM ubuntu:20.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive
ENV USER="docker"

RUN apt update && apt install -y sudo

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


RUN adduser --disabled-password --gecos '' $USER
RUN adduser $USER sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER $USER

# this is where I was running into problems with the other approaches
RUN sudo apt update 

# Install OpenJDK 17
RUN sudo apt-get update && sudo apt-get install -y openjdk-17-jdk && sudo rm -rf /var/lib/apt/lists/*

# Install bundletool
RUN sudo wget https://github.com/google/bundletool/releases/download/1.15.5/bundletool-all-1.15.5.jar -O /usr/local/bin/bundletool.jar
RUN sudo sh -c 'echo "#!/bin/sh\njava -jar /usr/local/bin/bundletool.jar \"$@\"" > /usr/local/bin/bundletool'
RUN sudo chmod +x /usr/local/bin/bundletool


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
RUN sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# Clean up existing app directory
RUN rm -rf ~/app

# Clone the Bull Bitcoin mobile repository
RUN git clone https://github.com/SatoshiPortal/bullbitcoin-mobile ~/app

# Copy device-spec.json into the container
COPY device-spec.json ~/app/device-spec.json

WORKDIR /home/$USER/app

RUN flutter pub get

# Generate a fake keystore
RUN keytool -genkey -v -keystore ~/app/android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload -storepass android -keypass android -dname "CN=Android Debug,O=Android,C=US"

# Set up key.properties
RUN echo "storePassword=android" > ~/app/android/key.properties && \
    echo "keyPassword=android" >> ~/app/android/key.properties && \
    echo "keyAlias=upload" >> ~/app/android/key.properties && \
    echo "storeFile=~/app/upload-keystore.jks" >> ~/app/android/key.properties

# Pre-build the project to download all necessary dependencies
RUN flutter precache

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH=$JAVA_HOME/bin:$PATH

# Build the AAB (Android App Bundle)
RUN flutter build appbundle --release

# Generate split APKs
RUN bundletool build-apks --bundle=~/app/build/app/outputs/bundle/release/app-release.aab --output=~/app/app.apks --device-spec=~/app/device-spec.json

# Extract specific APKs
RUN unzip -p ~/app/app.apks splits/base-master.apk > ~/app/base.apk && \
    unzip -p ~/app/app.apks splits/base-armeabi_v7a.apk > ~/app/armeabi_v7a.apk && \
    unzip -p ~/app/app.apks splits/base-en.apk > ~/app/en.apk && \
    unzip -p ~/app/app.apks splits/base-xhdpi.apk > ~/app/xhdpi.apk

# Clean up
RUN rm ~/app/app.apks

# Create the output directory
RUN mkdir -p ~/app/build-output/

# Output the build artifacts
CMD ["sh", "-c", "cp ~/app/base.apk ~/app/armeabi_v7a.apk ~/app/en.apk ~/app/xhdpi.apk ~/app/build/app/outputs/bundle/release/app-release.aab ~/app/build-output/"]
