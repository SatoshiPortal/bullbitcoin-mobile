import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';
import 'package:primitives/primitives.dart' show Fingerprint;

/// One complete Bull backup, as the app understands it.
///
/// Every field is a typed entity owned by the domain that produces it. The
/// wire form lives in the data layer; nothing here is JSON text.
final class WalletBackupSnapshot {
  static const format = 'bullbitcoin.wallet_backup';
  static const currentVersion = 1;
  static const maximumTimestampSeconds = 253402300799;

  final Fingerprint parentFingerprint;
  final int createdAt;
  final KeychainManifest recoveryManifest;
  final List<WalletDefinition> externalWalletDefinitions;
  final WalletMetadataSnapshot? metadata;

  WalletBackupSnapshot({
    required this.parentFingerprint,
    required this.createdAt,
    required this.recoveryManifest,
    Iterable<WalletDefinition> externalWalletDefinitions = const [],
    this.metadata,
  }) : externalWalletDefinitions = List.unmodifiable(
         externalWalletDefinitions,
       ) {
    if (createdAt < 0 ||
        createdAt > maximumTimestampSeconds ||
        recoveryManifest.parentFingerprint != parentFingerprint) {
      throw ArgumentError.value(createdAt, 'WalletBackupSnapshot');
    }
  }
}
