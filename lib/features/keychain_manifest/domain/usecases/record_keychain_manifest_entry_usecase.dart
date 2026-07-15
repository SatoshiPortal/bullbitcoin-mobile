import 'package:bb_mobile/core/utils/clock.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_entry.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_request.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_entry_repository.dart';

class RecordKeychainManifestEntryUsecase {
  final KeychainManifestEntryRepository _repository;
  final Bip85RegistryFacade _bip85Registry;
  final Clock _clock;

  RecordKeychainManifestEntryUsecase({
    required this._repository,
    required this._bip85Registry,
    this._clock = const SystemClock(),
  });

  Future<void> execute(
    KeychainManifestReservedDerivationRequest request, {
    DateTime? now,
  }) async {
    final reservation = _reservationFor(request.reservationId);
    if (reservation.purpose != Bip85ReservationPurpose.walletSeed) {
      throw KeychainManifestReservationMismatchException(
        'wallet materialization does not match BIP85 reservation purpose',
      );
    }
    // The recorded path must be derivation-proven: refuse to persist a
    // recovery record whose reserved path was never actually derived.
    final derivedPath = KeychainManifestBip85Path.normalize(
      request.derivationPath,
    );
    if (!reservation.scope.matchesExactPath(derivedPath)) {
      throw KeychainManifestInvalidEntryException(
        'derived BIP85 path does not match the reservation path',
      );
    }
    if (request.materializations.isEmpty) {
      throw KeychainManifestInvalidEntryException(
        'at least one materialization is required',
      );
    }

    final timestamp = (now ?? _clock.nowUtc()).millisecondsSinceEpoch ~/ 1000;
    final entry = KeychainManifestEntry(
      parentFingerprint: request.parentFingerprint,
      bip85DerivationPath: reservation.scope.exactPath,
      reservationId: reservation.id,
      entryType: reservation.purpose.name,
      ownerFeature: reservation.owner.name,
      bip85Application: reservation.application.number,
      bip85Index: reservation.scope.segmentValue('index'),
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    final records = request.materializations
        .map((materialization) {
          return KeychainManifestWalletMaterializationRecord(
            entry: entry,
            walletMaterialization: KeychainManifestWalletMaterialization(
              walletId: materialization.walletId,
              entryId: entry.entryId,
              childSeedFingerprint: materialization.childSeedFingerprint,
              network: materialization.network.name,
              scriptType: materialization.scriptType.name,
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          );
        })
        .toList(growable: false);

    await _executeMany(records);
  }

  Future<void> _executeMany(
    List<KeychainManifestWalletMaterializationRecord> records,
  ) async {
    try {
      for (final record in records) {
        await _executeRecord(record);
      }
    } catch (e, stack) {
      log.warning(
        'Keychain manifest batch record failed',
        error: e,
        trace: stack,
      );
      rethrow;
    }
  }

  Future<void> _executeRecord(
    KeychainManifestWalletMaterializationRecord record,
  ) async {
    final byWallet = await _repository
        .fetchWalletMaterializationRecordByWalletId(record.walletId);
    if (byWallet != null) {
      if (byWallet.sameRecordAs(record)) {
        return;
      }
      throw KeychainManifestEntryConflictException(
        'wallet already has a different keychain manifest entry',
      );
    }

    try {
      await _repository.insertWalletMaterializationRecord(record);
    } on KeychainManifestDuplicateException {
      final insertedByWallet = await _repository
          .fetchWalletMaterializationRecordByWalletId(record.walletId);
      if (insertedByWallet != null && insertedByWallet.sameRecordAs(record)) {
        return;
      }
      throw KeychainManifestEntryConflictException(
        'keychain manifest entry conflicts with an existing entry',
      );
    }
  }

  Bip85Reservation _reservationFor(String reservationId) {
    final reservation = _bip85Registry.reservationById(reservationId);
    if (reservation == null) {
      throw KeychainManifestReservationMismatchException(
        'unknown BIP85 reservation id: $reservationId',
      );
    }
    return reservation;
  }
}
