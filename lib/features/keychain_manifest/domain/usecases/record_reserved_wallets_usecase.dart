import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_requests.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:primitives/primitives.dart';

final class RecordReservedWalletsUsecase {
  final KeychainManifestRepository _repository;

  const RecordReservedWalletsUsecase(this._repository);

  Future<Result<bool, KeychainManifestFailure>> execute({
    required String reservationId,
    required Fingerprint parentFingerprint,
    required String derivationPath,
    required List<KeychainManifestWalletBinding> wallets,
    KeychainManifestWriteOrigin origin = KeychainManifestWriteOrigin.local,
    DateTime? now,
  }) async {
    final reservation = Bip85Reservations.reservationById(reservationId);
    if (reservation == null ||
        !reservation.isWalletSeed ||
        reservation.path != derivationPath ||
        wallets.isEmpty) {
      return const Err(KeychainManifestUnknownReservationFailure());
    }
    final timestamp =
        (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch ~/ 1000;
    final entryId = '${parentFingerprint.hex}:$derivationPath';
    final entry = KeychainManifestEntry(
      parentFingerprint: parentFingerprint,
      bip85DerivationPath: derivationPath,
      reservationId: reservation.id,
      entryType: reservation.purpose.name,
      ownerFeature: reservation.owner.name,
      bip85Application: reservation.application,
      bip85Index: reservation.index,
      createdAt: timestamp,
      updatedAt: timestamp,
      materializations: wallets
          .map(
            (wallet) => KeychainManifestWallet(
              walletId: wallet.walletId,
              entryId: entryId,
              childSeedFingerprint: wallet.childSeedFingerprint,
              network: wallet.network,
              scriptType: wallet.scriptType,
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          )
          .toList(),
    );
    final current = await _repository.fetch(parentFingerprint);
    if (current case Err(:final failure)) return Err(failure);
    final existing =
        (current as Ok<List<KeychainManifestEntry>, KeychainManifestFailure>)
            .value
            .where((item) => item.entryId == entry.entryId)
            .firstOrNull;
    if (existing != null &&
        wallets.every(
          (wallet) =>
              existing.materializations.whereType<KeychainManifestWallet>().any(
                (item) =>
                    item.walletId == wallet.walletId &&
                    item.childSeedFingerprint == wallet.childSeedFingerprint &&
                    item.network == wallet.network &&
                    item.scriptType == wallet.scriptType,
              ),
        )) {
      return const Ok(false);
    }
    return (await _repository.save([entry], origin: origin)).map((_) => true);
  }
}
