part of 'key_server_cubit.dart';

enum KeyServerFlow {
  enter,
  confirm,
  recovery,
  delete;

  static KeyServerFlow fromString(String value) {
    return KeyServerFlow.values.firstWhere(
      (element) => element.name.toLowerCase() == value.toLowerCase(),
      orElse: () => KeyServerFlow.enter,
    );
  }
}

enum AuthInputType { pin, password, backupKey }

enum SecretStatus { initial, stored, recovered, deleted }

enum TorStatus { online, offline, connecting, disconnecting }

@freezed
sealed class KeyServerOperationStatus with _$KeyServerOperationStatus {
  const factory KeyServerOperationStatus.initial() = _Initial;
  const factory KeyServerOperationStatus.loading() = _Authenticating;
  const factory KeyServerOperationStatus.success({String? message}) = _Success;
  const factory KeyServerOperationStatus.failure({required String message}) =
      _Failure;
}

@freezed
class KeyServerState with _$KeyServerState {
  const factory KeyServerState({
    @Default(TorStatus.online) TorStatus torStatus,
    @Default(KeyServerFlow.enter) KeyServerFlow selectedFlow,
    @Default(AuthInputType.pin) AuthInputType authInputType,
    @Default(SecretStatus.initial) SecretStatus secretStatus,
    @Default(KeyServerOperationStatus.initial())
    KeyServerOperationStatus status,
    @Default(false) bool obscure,
    @Default('') String key,
    @Default('') String tempKey,
    @Default(false) bool isKeyConfirmed,
    @Default('') String backupKey,
    @Default('') String encrypted,
    DateTime? lastRequestTime,
    int? cooldownMinutes,
  }) = _KeyServerState;
  const KeyServerState._();

  KeyValidator get _validator => KeyValidator();

  bool get hasValidKeyLength => _validator.hasValidLength(key);
  bool get areKeysMatching => _validator.areKeysMatching(key, tempKey);

  bool get canProceed => switch (selectedFlow) {
        KeyServerFlow.enter => hasValidKeyLength,
        KeyServerFlow.confirm => hasValidKeyLength && areKeysMatching,
        KeyServerFlow.recovery => backupKey.isNotEmpty,
        KeyServerFlow.delete => hasValidKeyLength,
      };

  bool get isInCooldown {
    if (lastRequestTime == null || cooldownMinutes == null) return false;
    return DateTime.now().isBefore(
      lastRequestTime!.add(Duration(minutes: cooldownMinutes!)),
    );
  }
}
