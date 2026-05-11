FROM bull-tools

# Default "bull" matches the user baked into Containerfile.tools so canonical
# reproducible builds (make container-app with no --build-arg) are unaffected.
# The dev container passes USERNAME=${localEnv:USER} so SSH / gitconfig mounts
# at /home/$USER/... inside the container resolve correctly.
ARG USERNAME="bull"

USER root
RUN if [ "$USERNAME" != "bull" ]; then \
      usermod -l "$USERNAME" -d "/home/$USERNAME" -m bull && \
      groupmod -n "$USERNAME" bull && \
      ln -sf "/home/$USERNAME" /home/bull && \
      echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME"; \
    fi
ENV USER=$USERNAME
USER $USERNAME

ARG GRADLE_HEAP=4g

COPY --chown=$USERNAME:$USERNAME . /app/
WORKDIR /app

# Install Flutter version specified in .fvmrc (no-op if it matches tools stage)
RUN fvm install

# Reuse makefile targets so container build matches local setup
RUN make deps
RUN make build-runner
RUN make translations

# Configure Gradle for containerized builds
RUN mkdir -p $HOME/.gradle && \
    echo "org.gradle.daemon=false" > $HOME/.gradle/gradle.properties && \
    echo "org.gradle.jvmargs=-Xmx${GRADLE_HEAP} -XX:+HeapDumpOnOutOfMemoryError" >> $HOME/.gradle/gradle.properties
