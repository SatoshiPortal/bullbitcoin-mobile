import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:primitives/primitives.dart';

final class RecordKeychainManifestNostrKeyUsecase {
  final KeychainManifestRepository _repository;

  const RecordKeychainManifestNostrKeyUsecase(this._repository);

  Future<Result<bool, KeychainManifestFailure>> execute({
    required String reservationId,
    required Fingerprint parentFingerprint,
    required String derivationPath,
    required String publicKeyHex,
    required KeychainManifestNostrKeyKind keyKind,
    required String purpose,
    String? description,
    KeychainManifestWriteOrigin origin = KeychainManifestWriteOrigin.local,
    DateTime? now,
    DateTime? updatedAt,
  }) async {
    final reservation = Bip85Reservations.reservationById(reservationId);
    final userKey =
        reservationId == Bip85Reservations.nostrUserKeyReservationId &&
        keyKind == KeychainManifestNostrKeyKind.userGenerated &&
        Bip85Reservations.isNostrUserKeyPath(derivationPath);
    final reservedKey =
        keyKind == KeychainManifestNostrKeyKind.reserved &&
        reservation?.purpose == Bip85ReservationPurpose.nonWalletNostrKey &&
        reservation?.path == derivationPath;
    if (!userKey && !reservedKey) {
      return const Err(KeychainManifestUnknownReservationFailure());
    }
    final effectiveNow = now ?? DateTime.now().toUtc();
    final timestamp = effectiveNow.millisecondsSinceEpoch ~/ 1000;
    final revision = (updatedAt ?? effectiveNow).millisecondsSinceEpoch ~/ 1000;
    final entryId = '${parentFingerprint.hex}:$derivationPath';
    final key = KeychainManifestNostrKey(
      entryId: entryId,
      publicKeyHex: publicKeyHex,
      keyKind: keyKind,
      purpose: purpose,
      createdAt: timestamp,
      updatedAt: revision,
    );
    final entry = KeychainManifestEntry(
      parentFingerprint: parentFingerprint,
      derivationPath: derivationPath,
      description: description,
      createdAt: timestamp,
      updatedAt: revision,
      materializations: [key],
    );
    final current = await _repository.fetch(parentFingerprint);
    if (current case Err(:final failure)) return Err(failure);
    final storedEntry =
        (current as Ok<List<KeychainManifestEntry>, KeychainManifestFailure>)
            .value
            .where((item) => item.entryId == entryId)
            .firstOrNull;
    final stored = storedEntry?.materializations
        .whereType<KeychainManifestNostrKey>()
        .firstOrNull;
    if (stored == null) {
      return (await _repository.insertNostrKey(
        entry,
        origin: origin,
      )).map((_) => true);
    }
    if (stored.publicKeyHex != publicKeyHex.toLowerCase() ||
        stored.keyKind != keyKind) {
      return const Err(KeychainManifestConflictFailure());
    }
    final metadataMatches =
        stored.purpose == key.purpose &&
        storedEntry!.description == entry.description;
    if (metadataMatches) return const Ok(false);
    if (stored.updatedAt == revision) {
      return const Err(KeychainManifestConflictFailure());
    }
    if (revision <= stored.updatedAt) return const Ok(false);
    return (await _repository.updateNostrMetadata(
      parentFingerprint: parentFingerprint,
      entryId: entryId,
      purpose: key.purpose,
      description: entry.description,
      updatedAt: revision,
      origin: origin,
    )).map((_) => true);
  }
}
