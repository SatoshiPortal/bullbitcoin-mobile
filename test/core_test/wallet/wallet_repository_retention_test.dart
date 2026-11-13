import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/ports/wallet_retention_port.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_mutation_guard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Err, Fingerprint;

class _Metadata extends Mock implements WalletMetadataDatasource {}

class _Bdk extends Mock implements BdkWalletDatasource {}

class _Lwk extends Mock implements LwkWalletDatasource {}

class _Servers extends Mock implements ElectrumServersPort {}

class _Retention implements WalletRetentionPort {
  _Retention(this.fail);
  final bool fail;
  @override
  Future<bool> retainsWallet(String walletId) async {
    if (fail) throw StateError('private details');
    return true;
  }

  @override
  Future<bool> retainsSecret(Fingerprint secretId) async => false;
}

void main() {
  for (final failure in [false, true]) {
    test(
      'repository refuses before native deletion when retained or unknown: error=$failure',
      () async {
        final metadata = _Metadata();
        final bdk = _Bdk();
        final lwk = _Lwk();
        when(
          () => bdk.walletSyncFinishedStream,
        ).thenAnswer((_) => const Stream<String>.empty());
        when(
          () => lwk.walletSyncFinishedStream,
        ).thenAnswer((_) => const Stream<String>.empty());
        final repository = WalletRepository(
          walletMetadataDatasource: metadata,
          bdkWalletDatasource: bdk,
          lwkWalletDatasource: lwk,
          serversPort: _Servers(),
          mutationGuard: WalletMutationGuard(),
          retention: _Retention(failure),
        );
        final result = await repository.deleteWallet(walletId: 'wallet');
        expect(result, isA<Err<void, WalletFailure>>());
        verifyNever(() => metadata.fetch(any()));
      },
    );
  }
}
