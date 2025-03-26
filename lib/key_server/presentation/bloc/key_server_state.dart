part of 'key_server_cubit.dart';

enum CurrentKeyServerFlow {
  enter,
  confirm,
  recovery,
  recoveryWithBackupKey,
  delete;

  static CurrentKeyServerFlow fromString(String value) {
    return CurrentKeyServerFlow.values.firstWhere(
      (element) => element.name.toLowerCase() == value.toLowerCase(),
      orElse: () => CurrentKeyServerFlow.enter,
    );
  }
}

enum AuthInputType { pin, password, backupKey }

enum SecretStatus { initial, stored, recovered, deleted }

enum TorStatus { online, offline, connecting, disconnecting }

@freezed
sealed class KeyServerOperationStatus with _$KeyServerOperationStatus {
  const factory KeyServerOperationStatus.initial() = _Initial;
  const factory KeyServerOperationStatus.loading() = _Loading;
  const factory KeyServerOperationStatus.success({String? message}) = _Success;
  const factory KeyServerOperationStatus.failure({required String message}) =
      _Failure;
}

@freezed
class KeyServerState with _$KeyServerState {
  const factory KeyServerState({
    @Default(TorStatus.online) TorStatus torStatus,
    @Default(CurrentKeyServerFlow.enter) CurrentKeyServerFlow currentFlow,
    @Default(AuthInputType.pin) AuthInputType authInputType,
    @Default(SecretStatus.initial) SecretStatus secretStatus,
    @Default(KeyServerOperationStatus.initial())
    KeyServerOperationStatus status,
    @Default(false) bool isSecretObscured,
    @Default('') String secret,
    @Default('') String temporarySecret,
    @Default('') String backupKey,
    @Default('') String encrypted,
    DateTime? lastRequestTime,
    int? cooldownMinutes,
  }) = _KeyServerState;
  const KeyServerState._();

  KeyValidator get _validator => KeyValidator();
  bool get hasValidKeyLength => _validator.hasValidLength(secret);
  bool get areKeysMatching =>
      _validator.areKeysMatching(secret, temporarySecret);
  bool get isInCommonPasswordList => _validator.isInCommonPasswordList(secret);
  bool get canProceed => switch (currentFlow) {
        CurrentKeyServerFlow.enter =>
          hasValidKeyLength && !isInCommonPasswordList,
        CurrentKeyServerFlow.confirm => areKeysMatching,
        CurrentKeyServerFlow.recovery =>
          authInputType == AuthInputType.backupKey
              ? backupKey.isNotEmpty
              : hasValidKeyLength,
        CurrentKeyServerFlow.delete => hasValidKeyLength,
        // TODO: Handle this case.
        CurrentKeyServerFlow.recoveryWithBackupKey => backupKey.isNotEmpty
      };

  bool get isInCooldown {
    if (lastRequestTime == null || cooldownMinutes == null) return false;
    return DateTime.now().isBefore(
      lastRequestTime!.add(Duration(minutes: cooldownMinutes!)),
    );
  }
}
