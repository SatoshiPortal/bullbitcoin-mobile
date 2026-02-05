# Verification tools container for reproducible build verification
# Contains: apktool, apksigner, bundletool, Java 17

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies
RUN apt-get update && apt-get install -y \
    openjdk-17-jdk \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install apktool
RUN wget -q https://raw.githubusercontent.com/iBotPeaches/Apktool/master/scripts/linux/apktool -O /usr/local/bin/apktool \
    && chmod +x /usr/local/bin/apktool \
    && wget -q https://bitbucket.org/iBotPeaches/apktool/downloads/apktool_2.9.3.jar -O /usr/local/bin/apktool.jar

# Install Android SDK command-line tools (for apksigner)
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH=$PATH:$ANDROID_HOME/build-tools/35.0.0

RUN mkdir -p ${ANDROID_HOME}/cmdline-tools \
    && wget -q https://dl.google.com/android/repository/commandlinetools-linux-8092744_latest.zip -O /tmp/cmdline-tools.zip \
    && unzip -q /tmp/cmdline-tools.zip -d ${ANDROID_HOME}/cmdline-tools \
    && mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest \
    && rm /tmp/cmdline-tools.zip

RUN yes | ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager --licenses > /dev/null 2>&1 \
    && ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager "build-tools;35.0.0" > /dev/null

# Install bundletool
RUN wget -q https://github.com/google/bundletool/releases/download/1.17.2/bundletool-all-1.17.2.jar -O /usr/local/bin/bundletool.jar

# Create wrapper scripts
RUN echo '#!/bin/bash\njava -jar /usr/local/bin/bundletool.jar "$@"' > /usr/local/bin/bundletool \
    && chmod +x /usr/local/bin/bundletool

WORKDIR /work
