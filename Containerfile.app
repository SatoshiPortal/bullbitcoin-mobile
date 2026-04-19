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

COPY --chown=$USERNAME:$USERNAME . /app/
WORKDIR /app

# Install Flutter version specified in .fvmrc
RUN fvm install

# Setup the project
RUN fvm flutter pub get
RUN fvm dart run build_runner build --delete-conflicting-outputs
RUN fvm flutter gen-l10n
