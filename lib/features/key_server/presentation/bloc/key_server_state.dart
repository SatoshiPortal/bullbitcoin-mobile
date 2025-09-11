part of 'key_server_cubit.dart';

// TODO; movethis enum to core

@freezed
sealed class KeyServerOperationStatus with _$KeyServerOperationStatus {
  const factory KeyServerOperationStatus.initial() = KeyServerIntialized;
  const factory KeyServerOperationStatus.loading() = KeyServerLoading;
  const factory KeyServerOperationStatus.success({String? message}) =
      KeyServerOK;
  const factory KeyServerOperationStatus.failure({required String message}) =
      KeyServerFailure;
}

@freezed
abstract class KeyServerState with _$KeyServerState {
  const factory KeyServerState({
    @Default(TorStatus.offline) TorStatus torStatus,
    @Default(CurrentKeyServerFlow.enter) CurrentKeyServerFlow currentFlow,
    @Default(AuthInputType.pin) AuthInputType authInputType,
    @Default(SecretStatus.initial) SecretStatus secretStatus,
    @Default(KeyServerOperationStatus.initial())
    KeyServerOperationStatus status,
    @Default(false) bool isPasswordObscured,
    @Default('') String password,
    @Default('') String temporaryPassword,
    @Default('') String vaultKey,
    @Default(null) EncryptedVault? vault,
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
      authInputType == AuthInputType.encryptionKey
          ? vaultKey.isNotEmpty
          : hasValidPasswordLength,
    CurrentKeyServerFlow.delete => hasValidPasswordLength,
    CurrentKeyServerFlow.recoveryWithBackupKey => vaultKey.isNotEmpty,
  };

  bool get isInCooldown {
    if (lastRequestTime == null || cooldownMinutes == null) return false;
    return DateTime.now().isBefore(
      lastRequestTime!.add(Duration(minutes: cooldownMinutes!)),
    );
  }
}
