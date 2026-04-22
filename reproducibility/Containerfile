# Verification tools container for reproducible build verification
# Contains: apktool, bundletool, Java 21

FROM --platform=linux/amd64 ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    openjdk-21-jdk \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# TODO: verify SHA256 checksums of downloaded jars and SDK zip for supply-chain integrity
# Install apktool
RUN curl -sL https://github.com/iBotPeaches/Apktool/releases/download/v2.10.0/apktool_2.10.0.jar -o /usr/local/bin/apktool.jar && \
    echo '#!/bin/sh' > /usr/local/bin/apktool && \
    echo 'java -jar /usr/local/bin/apktool.jar "$@"' >> /usr/local/bin/apktool && \
    chmod +x /usr/local/bin/apktool

# Install bundletool
RUN curl -sL https://github.com/google/bundletool/releases/download/1.17.2/bundletool-all-1.17.2.jar -o /usr/local/bin/bundletool.jar && \
    echo '#!/bin/sh' > /usr/local/bin/bundletool && \
    echo 'java -jar /usr/local/bin/bundletool.jar "$@"' >> /usr/local/bin/bundletool && \
    chmod +x /usr/local/bin/bundletool

WORKDIR /work
