import 'package:primitives/primitives.dart';

/// Wallets sharing one recovery secret, backed up in one encrypted file.
final class BackupGroup {
  /// Opaque and stable across launches; never derived from key material.
  final String id;
  final String displayName;
  final BitcoinNetwork network;
  final List<String> bitcoinWalletIds;

  /// Liquid wallets of the same secret: their labels travel in the vendor
  /// item of this group. Their confidential descriptors never leave the app.
  final List<String> liquidWalletIds;

  /// Public descriptors only; they are the BIP138 recipient keys.
  final List<String> bitcoinPublicDescriptors;
  final bool seedBackupVerified;

  BackupGroup({
    required this.id,
    required this.displayName,
    required this.network,
    required List<String> bitcoinWalletIds,
    required List<String> liquidWalletIds,
    required List<String> bitcoinPublicDescriptors,
    required this.seedBackupVerified,
  }) : bitcoinWalletIds = List.unmodifiable(bitcoinWalletIds),
       liquidWalletIds = List.unmodifiable(liquidWalletIds),
       bitcoinPublicDescriptors = List.unmodifiable(bitcoinPublicDescriptors) {
    if (id.isEmpty) throw ArgumentError('Backup group id must not be empty');
    if (bitcoinWalletIds.isEmpty || bitcoinPublicDescriptors.isEmpty) {
      throw ArgumentError('A backup group needs a Bitcoin account');
    }
  }
}

enum UnsupportedReason { silentPayments, noBitcoinAccount, other }

final class UnsupportedWallet {
  final String walletId;
  final UnsupportedReason reason;

  const UnsupportedWallet({required this.walletId, required this.reason});
}

final class BackupInventory {
  final List<BackupGroup> groups;
  final List<UnsupportedWallet> unsupported;

  BackupInventory({
    required List<BackupGroup> groups,
    required List<UnsupportedWallet> unsupported,
  }) : groups = List.unmodifiable(groups),
       unsupported = List.unmodifiable(unsupported);
}
