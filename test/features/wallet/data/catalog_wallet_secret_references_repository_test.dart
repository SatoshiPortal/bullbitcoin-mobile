import 'package:bb_mobile/features/wallet/data/catalog_wallet_secret_references_repository.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Metadata extends Mock implements WalletMetadataDatasource {}

// Network/origin getters intentionally absent: even an unresolved catalog row
// can reference custody used on another chain, and must not be decoded here.
class _Row extends Fake implements WalletMetadataModel {
  @override
  final String masterFingerprint;
  _Row(this.masterFingerprint);
}

void main() {
  test(
    'all-network references deduplicate without decoding wallet origins',
    () async {
      final metadata = _Metadata();
      when(() => metadata.fetchAll()).thenAnswer(
        (_) async => [
          _Row('73C5DA0A'),
          _Row('73c5da0a'),
          _Row('deadbeef'),
          _Row(''),
        ],
      );
      final result = await CatalogWalletSecretReferencesRepository(metadata)
          .list();
      expect((result as Ok<List<Fingerprint>, WalletFailure>).value, [
        Fingerprint('73c5da0a'),
        Fingerprint('deadbeef'),
      ]);
    },
  );
}
