import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/nostr_key_deriver.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:primitives/primitives.dart';

final class GetDefaultWalletNostrKeysUsecase {
  final KeychainManifestNostrKeyDeriver _deriver;
  final KeychainManifestRepository _repository;

  const GetDefaultWalletNostrKeysUsecase(this._deriver, this._repository);

  Future<Result<List<KeychainManifestEntry>, KeychainManifestFailure>>
  execute() async {
    final source = await _deriver.source();
    return switch (source) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => (await _repository.fetch(value.fingerprint)).map(
        (entries) => entries
            .where(
              (entry) =>
                  entry.materializations.singleOrNull
                      is KeychainManifestNostrKey,
            )
            .toList(growable: false),
      ),
    };
  }
}
