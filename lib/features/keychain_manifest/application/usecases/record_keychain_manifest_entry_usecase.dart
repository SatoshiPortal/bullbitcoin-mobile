import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/application/application_errors.dart';
import 'package:bb_mobile/features/keychain_manifest/application/ports/keychain_manifest_entry_store.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_entry.dart';

class RecordReservedKeychainDerivationCommand {
  final String reservationId;
  final String parentFingerprint;
  final List<RecordKeychainManifestWalletMaterializationCommand>
  walletMaterializations;

  const RecordReservedKeychainDerivationCommand({
    required this.reservationId,
    required this.parentFingerprint,
    required this.walletMaterializations,
  });
}

class RecordKeychainManifestWalletMaterializationCommand {
  final String walletId;
  final String childSeedFingerprint;
  final String network;
  final String walletPurpose;
  final String scriptType;

  const RecordKeychainManifestWalletMaterializationCommand({
    required this.walletId,
    required this.childSeedFingerprint,
    required this.network,
    required this.walletPurpose,
    required this.scriptType,
  });
}

class RecordKeychainManifestEntryUsecase {
  final KeychainManifestEntryStore _store;
  final Bip85RegistryFacade _bip85Registry;

  RecordKeychainManifestEntryUsecase({
    required this._store,
    this._bip85Registry = const Bip85RegistryFacade(),
  });

  Future<void> execute(
    RecordReservedKeychainDerivationCommand command, {
    DateTime? now,
  }) async {
    final reservation = _reservationFor(command.reservationId);
    if (reservation.purpose != Bip85ReservationPurpose.walletSeed) {
      throw KeychainManifestReservationMismatchException(
        'wallet materialization does not match BIP85 reservation purpose',
      );
    }
    if (command.walletMaterializations.isEmpty) {
      throw const KeychainManifestEntryConflictException(
        'at least one materialization is required',
      );
    }

    final timestamp =
        (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch ~/ 1000;
    final entry = KeychainManifestEntry(
      parentFingerprint: command.parentFingerprint,
      bip85DerivationPath: reservation.scope.exactPath,
      reservationId: reservation.id,
      entryType: reservation.purpose.name,
      ownerFeature: reservation.owner.name,
      bip85Application: reservation.application.number,
      bip85Index: reservation.scope.segmentValue('index'),
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    final records = command.walletMaterializations
        .map((materialization) {
          return KeychainManifestWalletMaterializationRecord(
            entry: entry,
            walletMaterialization: KeychainManifestWalletMaterialization(
              walletId: materialization.walletId,
              entryId: entry.entryId,
              childSeedFingerprint: materialization.childSeedFingerprint,
              network: materialization.network,
              walletPurpose: materialization.walletPurpose,
              scriptType: materialization.scriptType,
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
    _validateReservation(record.entry);

    final byWallet = await _store.fetchWalletMaterializationRecordByWalletId(
      record.walletId,
    );
    if (byWallet != null) {
      if (byWallet.sameRecordAs(record)) {
        return;
      }
      throw const KeychainManifestEntryConflictException(
        'wallet already has a different keychain manifest entry',
      );
    }

    try {
      await _store.insertWalletMaterializationRecord(record);
    } on KeychainManifestDuplicateException {
      final insertedByWallet = await _store
          .fetchWalletMaterializationRecordByWalletId(record.walletId);
      if (insertedByWallet != null && insertedByWallet.sameRecordAs(record)) {
        return;
      }
      throw const KeychainManifestEntryConflictException(
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

  void _validateReservation(KeychainManifestEntry entry) {
    final reservation = _bip85Registry.reservationById(entry.reservationId);
    if (reservation == null) {
      throw KeychainManifestReservationMismatchException(
        'unknown BIP85 reservation id: ${entry.reservationId}',
      );
    }
    if (!reservation.scope.matchesExactPath(entry.bip85DerivationPath)) {
      throw KeychainManifestReservationMismatchException(
        'BIP85 reservation does not match manifest entry path',
      );
    }
    if (reservation.application.number != entry.bip85Application) {
      throw KeychainManifestReservationMismatchException(
        'BIP85 reservation application does not match manifest entry',
      );
    }
    if (reservation.scope.segmentValue('index') != entry.bip85Index) {
      throw KeychainManifestReservationMismatchException(
        'BIP85 reservation index does not match manifest entry',
      );
    }
  }
}
