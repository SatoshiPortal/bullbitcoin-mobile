import 'package:bb_mobile/_pkg/consts/passwords.dart';
import 'package:bb_mobile/recoverbull/bloc/keychain_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:recoverbull/recoverbull.dart';

part 'keychain_state.freezed.dart';

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
class KeychainState with _$KeychainState {
  const factory KeychainState({
    @Default(false) bool loading,
    @Default(TorStatus.online) TorStatus torStatus,
    @Default(KeyChainFlow.enter) KeyChainFlow selectedKeyChainFlow,
    @Default(AuthInputType.pin) AuthInputType authInputType,
    @Default(SecretStatus.initial) SecretStatus secretStatus,
    @Default('') String secret,
    @Default('') String tempSecret,
    @Default(false) bool isSecretConfirmed,
    @Default(false) bool obscure,
    @Default('') String backupKey,
    @Default('') String error,
    DateTime? lastRequestTime,
    BullBackup? backupData,
    int? cooldownMinutes,
  }) = _KeychainState;

  const KeychainState._();

  String displayPin() => 'x' * secret.length;

  String? getValidationError() {
    // Skip validation during recovery, delete or download
    if (selectedKeyChainFlow == KeyChainFlow.recovery ||
        selectedKeyChainFlow == KeyChainFlow.delete) {
      return null;
    }

    if (secret.isEmpty) return null;

    if (authInputType == AuthInputType.pin) {
      const pinMin = KeychainCubit.pinMin;
      const pinMax = KeychainCubit.pinMax;

      if (!RegExp('^[0-9]{$pinMin,$pinMax}\$').hasMatch(secret)) {
        return secret.length < pinMin
            ? 'PIN must be at least $pinMin digits long'
            : 'Switch to password if you want more than $pinMax digits';
      }
    }

    return validateSecret(secret)
        ? 'The password is among the top 1000 most common'
        : null;
  }

  bool get isValid => getValidationError() == null;

  bool get hasError => error.isNotEmpty;
  bool get isRecovering => selectedKeyChainFlow == KeyChainFlow.recovery;
  bool get canStoreKey => isValid && !loading;
  bool get canRecoverKey => backupData != null && !loading;
  bool get canRecoverWithBckupKey => backupData != null && !loading;
  bool get canDeleteKey => backupData != null && !loading;
  bool get keyServerUp => torStatus == TorStatus.online;
  bool validateSecret(String secret) => commonPasswordsTop1000.contains(secret);

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
