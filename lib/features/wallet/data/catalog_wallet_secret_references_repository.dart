import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_secret_references_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

/// Secret references come from all catalog rows, including other networks and
/// unresolved legacy rows. No native wallet or secret enumeration is needed.
final class CatalogWalletSecretReferencesRepository
    implements WalletSecretReferencesRepository {
  final WalletMetadataDatasource _metadata;

  CatalogWalletSecretReferencesRepository(this._metadata);

  @override
  Future<Result<List<Fingerprint>, WalletFailure>> list() async {
    try {
      final fingerprints = <Fingerprint>{};
      for (final row in await _metadata.fetchAll()) {
        final fingerprint = Fingerprint.tryParse(row.masterFingerprint);
        if (fingerprint != null) fingerprints.add(fingerprint);
      }
      return Ok(List.unmodifiable(fingerprints));
    } on Exception {
      log.warning('Network wallet setup unavailable category=catalogRead');
      return const Err(WalletStorageFailure());
    }
  }
}
