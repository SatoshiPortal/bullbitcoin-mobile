import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_requests.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:primitives/primitives.dart';

/// Records one wallet the user made rather than one the app derived: a
/// passphrase wallet, or an imported mnemonic no re-derivation would produce.
final class RecordPassphraseWalletUsecase {
  final KeychainManifestRepository _repository;

  const RecordPassphraseWalletUsecase(this._repository);

  Future<Result<bool, KeychainManifestFailure>> execute({
    required Fingerprint parentFingerprint,
    required KeychainManifestWalletInventoryBinding wallet,
    DateTime? now,
  }) async {
    final timestamp =
        (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch ~/ 1000;
    final entry = wallet.isRecordable
        ? wallet.tryToEntry(parentFingerprint, fallbackTimestamp: timestamp)
        : null;
    if (entry == null) return const Err(KeychainManifestConflictFailure());
    return (await _repository.upsertPassphraseWallet(entry)).map((_) => true);
  }
}
