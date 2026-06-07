import 'package:bb_mobile/core/utils/clock.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_entry_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_entry.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_file.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_reservation_support.dart';

class BuildKeychainManifestFileUsecase {
  final KeychainManifestEntryRepository repository;
  final Bip85RegistryFacade registry;
  final Clock _clock;

  const BuildKeychainManifestFileUsecase({
    required this.repository,
    required this.registry,
    this._clock = const SystemClock(),
  });

  Future<KeychainManifestFile> execute(
    String parentFingerprint, {
    DateTime? now,
  }) async {
    final generatedAt = (now ?? _clock.nowUtc()).millisecondsSinceEpoch ~/ 1000;
    final normalizedParentFingerprint = KeychainManifestFingerprint.normalize(
      parentFingerprint,
    );
    final records = await repository
        .fetchWalletMaterializationRecordsByParentFingerprint(
          normalizedParentFingerprint,
        );
    final entries = _entriesFromRecords(_exportableRecords(records));
    return KeychainManifestFile(
      parentFingerprint: normalizedParentFingerprint,
      generatedAt: generatedAt,
      entries: entries,
    );
  }

  List<KeychainManifestFileEntry> _entriesFromRecords(
    List<KeychainManifestWalletMaterializationRecord> records,
  ) {
    final grouped =
        <String, List<KeychainManifestWalletMaterializationRecord>>{};
    for (final record in records) {
      grouped.putIfAbsent(record.entry.entryId, () => []).add(record);
    }
    final entries = grouped.values
        .map((recordsForEntry) {
          recordsForEntry.sort(_compareRecordsForMaterializationOrder);
          final materializations = recordsForEntry
              .map(KeychainManifestFileWalletMaterialization.fromRecord)
              .toList(growable: false);
          return KeychainManifestFileEntry.fromRecord(
            recordsForEntry.first,
            materializations: materializations,
          );
        })
        .toList(growable: false);
    entries.sort((left, right) {
      final pathCompare = left.bip85DerivationPath.compareTo(
        right.bip85DerivationPath,
      );
      if (pathCompare != 0) return pathCompare;
      return left.entryId.compareTo(right.entryId);
    });
    return entries;
  }

  List<KeychainManifestWalletMaterializationRecord> _exportableRecords(
    List<KeychainManifestWalletMaterializationRecord> records,
  ) {
    final exportable = <KeychainManifestWalletMaterializationRecord>[];
    final dropped = <String, int>{};
    for (final record in records) {
      final reservation = registry.reservationById(record.entry.reservationId);
      if (reservation != null &&
          KeychainManifestReservationSupport.supportsV1Export(reservation)) {
        exportable.add(record);
      } else {
        // Last-line tripwire (KC-3/R2-KC3b): should be dead after AD-4 classifies
        // every wallet-seed reservation. A drop here means a recordable product
        // wallet would be silently excluded from backup - surface it loudly.
        dropped.update(
          record.entry.reservationId,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
    if (dropped.isNotEmpty) {
      log.warning(
        'Keychain manifest export dropped unexportable reservations: $dropped',
      );
    }
    return List.unmodifiable(exportable);
  }

  int _compareRecordsForMaterializationOrder(
    KeychainManifestWalletMaterializationRecord left,
    KeychainManifestWalletMaterializationRecord right,
  ) {
    final networkCompare = left.walletMaterialization.network.compareTo(
      right.walletMaterialization.network,
    );
    if (networkCompare != 0) return networkCompare;
    return left.walletId.compareTo(right.walletId);
  }
}
