FROM bull-tools

COPY --chown=$USER:$USER . /app/
WORKDIR /app

# Install Flutter version specified in .fvmrc
RUN fvm install

# Setup the project
RUN fvm flutter pub get
RUN fvm dart run build_runner build --delete-conflicting-outputs
RUN fvm flutter gen-l10n
