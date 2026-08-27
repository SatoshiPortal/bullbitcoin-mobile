import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:primitives/primitives.dart';

final class GetKeychainManifestReservationWalletIdsUsecase {
  final KeychainManifestRepository _repository;

  const GetKeychainManifestReservationWalletIdsUsecase(this._repository);

  Future<Result<List<String>, KeychainManifestFailure>> execute({
    required Fingerprint parentFingerprint,
    required String reservationId,
  }) async => (await _repository.fetch(parentFingerprint)).map(
    (entries) => entries
        .where((entry) => entry.reservationId == reservationId)
        .expand((entry) => entry.materializations)
        .whereType<KeychainManifestWallet>()
        .map((wallet) => wallet.walletId)
        .toList(growable: false),
  );
}
