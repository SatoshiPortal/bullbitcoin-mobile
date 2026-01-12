part of 'secrets_view_bloc.dart';

@freezed
abstract class SecretsViewState with _$SecretsViewState {
  const factory SecretsViewState.initial() = SecretsViewInitial;
  const factory SecretsViewState.loading() = SecretsViewLoading;
  const factory SecretsViewState.failedToLoad({
    required SecretsPresentationError error,
  }) = SecretsViewFailedToLoad;
  const factory SecretsViewState.loaded({
    @Default({}) Map<String, Secret> secrets,
    @Default([]) List<String> inUseFingerprints,
    @Default(false) bool isSecretBeingDeleted,
    SecretsPresentationError? deletionError,
    @Default({}) Map<String, Secret> legacySecrets,
  }) = SecretsViewLoaded;
  const SecretsViewState._();

  bool get isInitial => this is SecretsViewInitial;
  bool get isLoading => this is SecretsViewLoading;
  bool get hasLoadError => this is SecretsViewFailedToLoad;
  bool get isLoaded => this is SecretsViewLoaded;
  bool get isSecretBeingDeleted {
    return maybeWhen(
      loaded:
          (
            secrets,
            inUseFingerprints,
            isSecretBeingDeleted,
            deletionError,
            legacySecrets,
          ) => isSecretBeingDeleted,
      orElse: () => false,
    );
  }

  List<SecretViewModel> get allSecrets {
    return maybeWhen(
      loaded:
          (
            secrets,
            inUseFingerprints,
            isSecretBeingDeleted,
            deletionError,
            legacySecrets,
          ) {
            final secretModels = secrets.entries
                .map(
                  (e) => SecretViewModel(
                    fingerprint: e.key,
                    secret: e.value,
                    isLegacy: false,
                    isInUse: inUseFingerprints.contains(e.key),
                  ),
                )
                .toList();
            final legacySecretModels = legacySecrets.entries
                .map(
                  (e) => SecretViewModel(
                    fingerprint: e.key,
                    secret: e.value,
                    isLegacy: true,
                    isInUse: false,
                  ),
                )
                .toList();

            return [...secretModels, ...legacySecretModels];
          },
      orElse: () => [],
    );
  }
}
