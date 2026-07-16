import 'package:bb_mobile/features/remote_keychain_recovery/domain/recovered_products_heal_outcome.dart';

enum RemoteKeychainRecoveryStatus {
  noBackup,
  unavailable,
  invalid,
  tooLarge,
  newerVersion,
  conflict,
  restored,
  partiallyRestored,
}

final class RemoteKeychainRecoveryResult {
  final RemoteKeychainRecoveryStatus status;
  final int restoredCount;
  final int failedCount;
  final List<String> createdWalletIds;
  final RecoveredProductsHealOutcome? healOutcome;

  const RemoteKeychainRecoveryResult({
    required this.status,
    this.restoredCount = 0,
    this.failedCount = 0,
    this.createdWalletIds = const [],
    this.healOutcome,
  });
}
