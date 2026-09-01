import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_requests.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:primitives/primitives.dart';

/// Restates the wallets this seed deterministically derives.
///
/// An empty list is legitimate — it says the seed derives nothing right now —
/// so it replaces rather than being rejected.
final class ReplaceSeedWalletInventoryUsecase {
  final KeychainManifestRepository _repository;

  const ReplaceSeedWalletInventoryUsecase(this._repository);

  Future<Result<bool, KeychainManifestFailure>> execute({
    required Fingerprint parentFingerprint,
    required List<KeychainManifestWalletInventoryBinding> wallets,
    DateTime? now,
  }) async {
    final timestamp =
        (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch ~/ 1000;
    final entries = <KeychainManifestEntry>[];
    for (final wallet in wallets) {
      final entry = wallet.isRecordable
          ? wallet.tryToEntry(parentFingerprint, fallbackTimestamp: timestamp)
          : null;
      if (entry == null) return const Err(KeychainManifestConflictFailure());
      entries.add(entry);
    }
    return (await _repository.replaceSeedWalletInventory(
      parentFingerprint,
      entries,
    )).map((_) => true);
  }
}
