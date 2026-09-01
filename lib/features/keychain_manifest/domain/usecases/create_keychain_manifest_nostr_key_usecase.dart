import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/nostr_key_deriver.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/record_keychain_manifest_nostr_key_usecase.dart';
import 'package:primitives/primitives.dart';

final class CreateKeychainManifestNostrKeyUsecase {
  final KeychainManifestNostrKeyDeriver _deriver;
  final KeychainManifestRepository _repository;
  final RecordKeychainManifestNostrKeyUsecase _record;

  const CreateKeychainManifestNostrKeyUsecase(
    this._deriver,
    this._repository,
    this._record,
  );

  Future<Result<KeychainManifestEntry, KeychainManifestFailure>> execute({
    required String purpose,
    String? description,
    DateTime? now,
  }) async {
    final sourceResult = await _deriver.source();
    if (sourceResult case Err(:final failure)) return Err(failure);
    final source =
        (sourceResult
                as Ok<KeychainManifestSeedSource, KeychainManifestFailure>)
            .value;
    while (true) {
      final fetched = await _repository.fetch(source.fingerprint);
      if (fetched case Err(:final failure)) return Err(failure);
      final entries =
          (fetched as Ok<List<KeychainManifestEntry>, KeychainManifestFailure>)
              .value;
      var identity =
          entries
              .where(
                (entry) =>
                    entry.derivationKind ==
                        KeychainManifestDerivationKind.bip85 &&
                    Bip85Reservations.isNostrUserKeyPath(entry.derivationPath),
              )
              .map(
                (entry) => Bip85Reservations.nostrUserKeyIdentity(
                  entry.derivationPath,
                ),
              )
              .whereType<int>()
              .fold(0, (largest, value) => value > largest ? value : largest) +
          1;
      if (Bip85Reservations.isNostrAppReservedIdentity(identity)) {
        identity = Bip85Reservations.nostrAppReservedIdentityEnd + 1;
      }
      if (identity > Bip85Reservations.nostrUserIdentityEnd) {
        return const Err(KeychainManifestConflictFailure());
      }
      final path = Bip85Reservations.nostrUserKeyPath(identity);
      final recorded = await _record.execute(
        reservationId: Bip85Reservations.nostrUserKeyReservationId,
        parentFingerprint: source.fingerprint,
        derivationPath: path,
        publicKeyHex: _deriver.derivePublicKey(source.seed, path),
        keyKind: KeychainManifestNostrKeyKind.userGenerated,
        purpose: purpose,
        description: description,
        now: now,
      );
      switch (recorded) {
        case Ok(:final value):
          if (!value) continue;
          final refreshed = await _repository.fetch(source.fingerprint);
          return refreshed.map(
            (entries) => entries.singleWhere(
              (entry) =>
                  entry.derivationKind ==
                      KeychainManifestDerivationKind.bip85 &&
                  entry.derivationPath == path,
            ),
          );
        case Err(failure: KeychainManifestConflictFailure()):
          continue;
        case Err(:final failure):
          return Err(failure);
      }
    }
  }
}
