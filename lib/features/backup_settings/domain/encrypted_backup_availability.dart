import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';

/// A historical backup can still be tested or opened without counting as a
/// verification recorded by the current RecoverBull feature.
final class EncryptedBackupAvailability {
  final bool hasEncryptedBackup;
  final bool hasVerifiedEncryptedBackup;

  const EncryptedBackupAvailability._({
    required this.hasEncryptedBackup,
    required this.hasVerifiedEncryptedBackup,
  });

  factory EncryptedBackupAvailability.fromStatus({
    required RecoverBullStatus status,
    required Network network,
    required Iterable<Wallet> defaultWallets,
  }) {
    final legacyAvailable = defaultWallets
        .where((wallet) => wallet.network == network)
        .any(
          (wallet) =>
              wallet.latestEncryptedBackup != null ||
              wallet.isEncryptedVaultTested,
        );
    return EncryptedBackupAvailability._(
      hasEncryptedBackup:
          (status.isKnown && status.hasEncryptedBackup) || legacyAvailable,
      hasVerifiedEncryptedBackup:
          status.isKnown && status.hasVerifiedEncryptedBackup,
    );
  }
}
