import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_requests.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:primitives/primitives.dart';

/// Edits the label and hint the manifest owns for one wallet (decision 2).
final class UpdatePassphraseLabelHintUsecase {
  final KeychainManifestRepository _repository;

  const UpdatePassphraseLabelHintUsecase(this._repository);

  /// A local edit is by definition the newest statement about the record, so
  /// the revision it writes is derived from the stored one rather than taken
  /// on trust from a clock that may be behind.
  Future<Result<void, KeychainManifestFailure>> execute({
    required Fingerprint parentFingerprint,
    required String walletId,
    KeychainManifestEdit<String?>? label,
    KeychainManifestEdit<String?>? hint,
    DateTime? now,
  }) async {
    if (label == null && hint == null) return const Ok(null);
    final current = await _repository.fetch(parentFingerprint);
    final List<KeychainManifestEntry> entries;
    switch (current) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        entries = value;
    }
    final stored = entries
        .where(
          (entry) => entry.materializations.any(
            (item) =>
                item is KeychainManifestWallet && item.walletId == walletId,
          ),
        )
        .firstOrNull;
    if (stored == null) return const Err(KeychainManifestConflictFailure());
    final seconds =
        (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch ~/ 1000;
    final revision = [
      stored.updatedAt,
      ...stored.materializations.map((item) => item.updatedAt),
    ].reduce((a, b) => a > b ? a : b);
    return _repository.updatePassphraseLabelHint(
      parentFingerprint: parentFingerprint,
      walletId: walletId,
      label: label,
      hint: hint,
      updatedAt: seconds > revision ? seconds : revision + 1,
    );
  }
}
