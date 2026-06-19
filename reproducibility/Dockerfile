# Verification tools container for reproducible build verification
# Contains: apktool, bundletool, Java 21

# Base pinned by digest for reproducibility (the `24.04` tag is rolling).
# Refresh: docker buildx imagetools inspect ubuntu:24.04 --format '{{.Manifest.Digest}}'
FROM --platform=linux/amd64 ubuntu:24.04@sha256:786a8b558f7be160c6c8c4a54f9a57274f3b4fb1491cf65146521ae77ff1dc54

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    openjdk-21-jdk \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Jars are pinned by version AND SHA256 — this image renders the reproducibility
# verdict, so its own inputs must be tamper-evident (a swapped release asset
# fails the checksum instead of silently altering the verifier).
# Install apktool
RUN curl -sL https://github.com/iBotPeaches/Apktool/releases/download/v2.10.0/apktool_2.10.0.jar -o /usr/local/bin/apktool.jar && \
    echo 'c0350abbab5314248dfe2ee0c907def4edd14f6faef1f5d372d3d4abd28f0431  /usr/local/bin/apktool.jar' | sha256sum -c - && \
    echo '#!/bin/sh' > /usr/local/bin/apktool && \
    echo 'java -jar /usr/local/bin/apktool.jar "$@"' >> /usr/local/bin/apktool && \
    chmod +x /usr/local/bin/apktool

# Install bundletool
RUN curl -sL https://github.com/google/bundletool/releases/download/1.17.2/bundletool-all-1.17.2.jar -o /usr/local/bin/bundletool.jar && \
    echo '2d4ad908faea64047c1cc9cb747e6aa667c6ab192e09607bd16b67246a8cd6ae  /usr/local/bin/bundletool.jar' | sha256sum -c - && \
    echo '#!/bin/sh' > /usr/local/bin/bundletool && \
    echo 'java -jar /usr/local/bin/bundletool.jar "$@"' >> /usr/local/bin/bundletool && \
    chmod +x /usr/local/bin/bundletool

WORKDIR /work
