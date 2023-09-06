FROM dart:stable
WORKDIR /usr/local/

RUN apt update
RUN apt install -y git openjdk-17-jdk unzip wget curl xz-utils
RUN dpkg --print-architecture
RUN dpkg --print-foreign-architectures
RUN dpkg --remove --force-depends libstdc++6-arm64-cross
RUN apt-get install --reinstall -y libstdc++6
RUN apt-get -f install
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y curl git wget unzip libgconf-2-4 gdb libstdc++6-arm64-cross libglu1-mesa fonts-droid-fallback libstdc++6-arm64-cross python3 sed
RUN apt-get clean
# RUN apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev

ENV ANDROID_COMMAND_LINE_TOOLS_FILENAME commandlinetools-linux-10406996_latest.zip
ENV ANDROID_API_LEVELS                  android-34
ENV ANDROID_BUILD_TOOLS_VERSION         34.0.0
ENV ANDROID_HOME                        /usr/local/android-sdk-linux
ENV PATH                                ${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/cmdline-tools/bin
ENV FLUTTER_VERSION                     flutter_linux_3.13.2-stable
ENV PATH                                ${PATH}:/usr/local/flutter/bin

RUN wget -q "https://dl.google.com/android/repository/${ANDROID_COMMAND_LINE_TOOLS_FILENAME}"
RUN unzip ${ANDROID_COMMAND_LINE_TOOLS_FILENAME} -d /usr/local/android-sdk-linux
RUN rm ${ANDROID_COMMAND_LINE_TOOLS_FILENAME}

RUN yes | sdkmanager --update --sdk_root="${ANDROID_HOME}"
RUN yes | sdkmanager --sdk_root="${ANDROID_HOME}" "platforms;${ANDROID_API_LEVELS}" "build-tools;${ANDROID_BUILD_TOOLS_VERSION}" "extras;google;m2repository" "extras;android;m2repository" "extras;google;google_play_services"
RUN yes | sdkmanager --licenses --sdk_root="${ANDROID_HOME}"

RUN rm -rf ${ANDROID_HOME}/tools

RUN wget -q https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${FLUTTER_VERSION}.tar.xz
RUN tar -xvf /usr/local/${FLUTTER_VERSION}.tar.xz
RUN git config --global --add safe.directory /usr/local/flutter
# RUN flutter --disable-telemetry
RUN flutter doctor
CMD ["tail", "-f", "/dev/null"]
