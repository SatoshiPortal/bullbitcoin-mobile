part of 'key_server_cubit.dart';

// TODO; movethis enum to core

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
    @Default(false) bool isPasswordObscured,
    @Default('') String password,
    @Default('') String temporaryPassword,
    @Default('') String backupKey,
    @Default('') String backupFile,
    DateTime? lastRequestTime,
    int? cooldownMinutes,
  }) = _KeyServerState;
  const KeyServerState._();

  PasswordValidator get _validator => PasswordValidator();
  bool get hasValidPasswordLength => _validator.hasValidLength(password);
  bool get arePasswordsMatching =>
      _validator.arePasswordsMatching(password, temporaryPassword);
  bool get isInCommonPasswordList =>
      _validator.isInCommonPasswordList(password);
  bool get canProceed => switch (currentFlow) {
        CurrentKeyServerFlow.enter =>
          hasValidPasswordLength && !isInCommonPasswordList,
        CurrentKeyServerFlow.confirm => arePasswordsMatching,
        CurrentKeyServerFlow.recovery =>
          authInputType == AuthInputType.backupKey
              ? backupKey.isNotEmpty
              : hasValidPasswordLength,
        CurrentKeyServerFlow.delete => hasValidPasswordLength,
        CurrentKeyServerFlow.recoveryWithBackupKey => backupKey.isNotEmpty
      };

  bool get isInCooldown {
    if (lastRequestTime == null || cooldownMinutes == null) return false;
    return DateTime.now().isBefore(
      lastRequestTime!.add(Duration(minutes: cooldownMinutes!)),
    );
  }
}
