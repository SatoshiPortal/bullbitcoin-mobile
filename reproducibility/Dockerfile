# Verification tools container for reproducible build verification
# Contains: apktool, apksigner, bundletool, Java 17

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH=$PATH:$ANDROID_HOME/build-tools/35.0.0

# Install base dependencies
RUN apt-get update && apt-get install -y \
    openjdk-17-jdk \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install apktool
RUN wget -q https://github.com/iBotPeaches/Apktool/releases/download/v2.10.0/apktool_2.10.0.jar -O /usr/local/bin/apktool.jar
RUN echo '#!/bin/sh' > /usr/local/bin/apktool && \
    echo 'java -jar /usr/local/bin/apktool.jar "$@"' >> /usr/local/bin/apktool && \
    chmod +x /usr/local/bin/apktool

# Install Android SDK command-line tools (for apksigner)
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-8092744_latest.zip -O /tmp/cmdline-tools.zip && \
    unzip -q /tmp/cmdline-tools.zip -d ${ANDROID_HOME}/cmdline-tools && \
    mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest && \
    rm /tmp/cmdline-tools.zip

RUN yes | ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager --licenses > /dev/null 2>&1 && \
    ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager "build-tools;35.0.0" > /dev/null

# Install bundletool
RUN wget -q https://github.com/google/bundletool/releases/download/1.17.2/bundletool-all-1.17.2.jar -O /usr/local/bin/bundletool.jar
RUN echo '#!/bin/sh' > /usr/local/bin/bundletool && \
    echo 'java -jar /usr/local/bin/bundletool.jar "$@"' >> /usr/local/bin/bundletool && \
    chmod +x /usr/local/bin/bundletool

WORKDIR /work
