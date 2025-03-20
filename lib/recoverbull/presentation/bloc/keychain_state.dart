part of 'keychain_cubit.dart';

enum KeyChainFlow {
  enter,
  confirm,
  recovery,
  delete;

  static KeyChainFlow fromString(String value) {
    return KeyChainFlow.values.firstWhere(
      (element) => element.name.toLowerCase() == value.toLowerCase(),
      orElse: () => KeyChainFlow.enter,
    );
  }
}

enum AuthInputType { pin, password, backupKey }

enum SecretStatus { initial, stored, recovered, deleted }

enum TorStatus { online, offline, connecting, disconnecting }

@freezed
sealed class KeychainOperationStatus with _$KeychainOperationStatus {
  const factory KeychainOperationStatus.initial() = _Initial;
  const factory KeychainOperationStatus.loading() = _Authenticating;
  const factory KeychainOperationStatus.success({String? message}) = _Success;
  const factory KeychainOperationStatus.failure({required String message}) =
      _Failure;
}

@freezed
class KeychainState with _$KeychainState {
  const factory KeychainState({
    @Default(TorStatus.online) TorStatus torStatus,
    @Default(KeyChainFlow.enter) KeyChainFlow selectedKeyChainFlow,
    @Default(AuthInputType.pin) AuthInputType authInputType,
    @Default(SecretStatus.initial) SecretStatus secretStatus,
    @Default(KeychainOperationStatus.initial()) KeychainOperationStatus status,
    @Default(false) bool obscure,
    @Default('') String secret,
    @Default('') String tempSecret,
    @Default(false) bool isSecretConfirmed,
    @Default('') String backupKey,
    @Default('') String encryted,
    DateTime? lastRequestTime,
    int? cooldownMinutes,
  }) = _KeychainState;
  KeychainState._();

  SecretValidator get _validator => SecretValidator();

  bool get hasValidSecretLength => _validator.hasValidLength(secret);
  bool get hasValidTempSecretLength => _validator.hasValidLength(tempSecret);
  bool get areSecretsMatching =>
      _validator.areSecretsMatching(secret, tempSecret);

  bool get canProceed => switch (selectedKeyChainFlow) {
        KeyChainFlow.enter => hasValidSecretLength,
        KeyChainFlow.confirm => hasValidSecretLength && areSecretsMatching,
        KeyChainFlow.recovery => backupKey.isNotEmpty,
        KeyChainFlow.delete => hasValidSecretLength,
      };

  // State updates
  KeychainState updateWithSecret(String value) => copyWith(
        secret: value,
        status: const KeychainOperationStatus.initial(),
        isSecretConfirmed: false,
      );

  KeychainState updateWithTempSecret(String value) => copyWith(
        tempSecret: value,
        isSecretConfirmed: areSecretsMatching && hasValidSecretLength,
        status: const KeychainOperationStatus.initial(),
      );

  KeychainState reset() => copyWith(
        secret: '',
        tempSecret: '',
        isSecretConfirmed: false,
        status: const KeychainOperationStatus.initial(),
        backupKey: '',
      );

  KeychainState setFlow(KeyChainFlow flow) => copyWith(
        selectedKeyChainFlow: flow,
        status: const KeychainOperationStatus.initial(),
      ).reset();

  KeychainState updateTorStatus(TorStatus status) => copyWith(
        torStatus: status,
        status: const KeychainOperationStatus.initial(),
      );
  bool get isInCooldown {
    if (lastRequestTime == null || cooldownMinutes == null) return false;
    final cooldownEnd =
        lastRequestTime!.add(Duration(minutes: cooldownMinutes!));
    return DateTime.now().isBefore(cooldownEnd);
  }

  int? get remainingCooldownSeconds {
    if (!isInCooldown) return null;
    final cooldownEnd =
        lastRequestTime!.add(Duration(minutes: cooldownMinutes!));
    return cooldownEnd.difference(DateTime.now()).inSeconds;
  }
}
