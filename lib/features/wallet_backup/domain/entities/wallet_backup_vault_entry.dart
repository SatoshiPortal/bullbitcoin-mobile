import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

/// One BullVault in the backup: the recovery package the vault feature itself
/// emits, verbatim, plus the facts needed to place and replay it without
/// decoding it here.
///
/// Every record of a lineage is carried, whatever its lifecycle status, so
/// predecessor links and late-deposit monitoring survive recovery (D2).
final class WalletBackupVaultEntry {
  static const maxLabelLength = 50;
  static const maxPackageLength = 8 * 1024;

  final String walletRef;
  final String? label;
  final String status;
  final Network network;
  final String lineageId;
  final int vaultGeneration;
  final String recoveryPackage;

  WalletBackupVaultEntry({
    required String walletRef,
    String? label,
    required String status,
    required this.network,
    required String lineageId,
    required this.vaultGeneration,
    required String recoveryPackage,
  }) : walletRef = walletRef.trim(),
       label = _optional(label),
       status = status.trim(),
       lineageId = lineageId.trim(),
       recoveryPackage = recoveryPackage.trim() {
    if (this.walletRef.isEmpty ||
        this.status.isEmpty ||
        this.lineageId.isEmpty ||
        vaultGeneration < 0 ||
        this.recoveryPackage.isEmpty ||
        this.recoveryPackage.length > maxPackageLength ||
        (this.label?.length ?? 0) > maxLabelLength) {
      throw ArgumentError('Invalid wallet backup vault entry');
    }
  }

  static String? _optional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// Lineage first, then generation: a predecessor is replayed before the
  /// vault that links to it.
  static int compare(
    WalletBackupVaultEntry left,
    WalletBackupVaultEntry right,
  ) {
    final lineage = left.lineageId.compareTo(right.lineageId);
    if (lineage != 0) return lineage;
    final generation = left.vaultGeneration.compareTo(right.vaultGeneration);
    return generation != 0
        ? generation
        : left.walletRef.compareTo(right.walletRef);
  }
}

/// What a recovery package says about itself, read by the vault feature's own
/// codec so the backup never re-implements the package format.
final class WalletBackupVaultPackageFacts {
  final Network network;
  final String lineageId;
  final int vaultGeneration;
  final String descriptor;
  final int? birthHeight;

  const WalletBackupVaultPackageFacts({
    required this.network,
    required this.lineageId,
    required this.vaultGeneration,
    required this.descriptor,
    required this.birthHeight,
  });
}
