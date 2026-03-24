FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive
ENV USER="bull"

ARG FVM_VERSION=4.0.5
ARG FLUTTER_VERSION=3.38.5
ARG ANDROID_CMDLINE_TOOLS_VERSION=14742923
ARG ANDROID_API_LEVEL=36
ARG ANDROID_BUILD_TOOLS=36.0.0
ARG ANDROID_NDK=29.0.14206865

ENV ANDROID_HOME=/opt/android-sdk
ENV PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools

# Install dependencies
RUN apt-get update && apt-get install -y \
    sudo \
    ca-certificates \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    wget \
    make \
    openjdk-21-jdk-headless \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create user
RUN adduser --disabled-password --gecos '' $USER && \
    adduser $USER sudo && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
USER $USER

# Install Rust and FVM (FVM installer sequential)
RUN set -eux; \
    echo "Downloading Rust and FVM installers..."; \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o /tmp/rustup.sh; \
    curl -fsSL https://fvm.app/install.sh -o /tmp/fvm-install.sh; \
    sudo wget -q https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip -O /tmp/android-cmdline-tools.zip; \
    echo "Running Rust and FVM installers..."; \
    sh /tmp/rustup.sh -y; \
    bash /tmp/fvm-install.sh ${FVM_VERSION}; \
    rm -f /tmp/rustup.sh /tmp/fvm-install.sh

ENV PATH="/home/$USER/.cargo/bin:/home/$USER/fvm/bin:${PATH}"
RUN rustc --version && cargo --version

# Install Flutter via FVM (sequential)
RUN fvm install ${FLUTTER_VERSION} && \
    fvm global ${FLUTTER_VERSION}
ENV PATH="/home/$USER/fvm/default/bin:/home/$USER/fvm/bin:${PATH}"

# Set up Android SDK
RUN sudo mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    sudo unzip -q /tmp/android-cmdline-tools.zip -d ${ANDROID_HOME}/cmdline-tools && \
    sudo mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest && \
    sudo rm /tmp/android-cmdline-tools.zip && \
    sudo chown -R $USER ${ANDROID_HOME}

# Accept licenses and install Android SDK components (sequential)
RUN yes | sdkmanager --sdk_root=${ANDROID_HOME} --licenses
RUN sdkmanager --sdk_root=${ANDROID_HOME} \
    "platform-tools" \
    "platforms;android-${ANDROID_API_LEVEL}" \
    "build-tools;${ANDROID_BUILD_TOOLS}" \
    "ndk;${ANDROID_NDK}"
