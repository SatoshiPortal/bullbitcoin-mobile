import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:primitives/primitives.dart';

final class RemovePassphraseWalletUsecase {
  final KeychainManifestRepository _repository;

  const RemovePassphraseWalletUsecase(this._repository);

  Future<Result<void, KeychainManifestFailure>> execute({
    required Fingerprint parentFingerprint,
    required String walletId,
  }) => _repository.removePassphraseWallet(
    parentFingerprint: parentFingerprint,
    walletId: walletId,
  );
}
