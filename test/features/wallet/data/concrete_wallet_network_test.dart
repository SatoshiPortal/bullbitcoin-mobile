import 'package:bb_mobile/features/wallet/data/sync_wallet_values_datasource.dart';
import 'package:sync/sync.dart' show SyncReason, WalletKey;
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, Fingerprint, Ok;
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Metadata extends Mock implements WalletMetadataDatasource {}

class _Values extends Mock implements SyncWalletValuesDatasource {}

WalletMetadataModel _row(Network network) {
  final origin = 'wpkh([73c5da0a/84h/${network.coinType}h/0h])';
  return WalletMetadataModel(
    id: network == Network.bitcoinRegtest ? '$origin:regtest' : origin,
    networkCode: network.name,
    masterFingerprint: '73c5da0a',
    xpubFingerprint: 'deadbeef',
    isEncryptedVaultTested: false,
    isPhysicalBackupTested: false,
    xpub: 'public-test-key',
    externalPublicDescriptor: 'wpkh(public-test-key/0/*)',
    internalPublicDescriptor: 'wpkh(public-test-key/1/*)',
    signer: Signer.local,
    isDefault: true,
  );
}

void main() {
  test(
    'catalog filtering distinguishes testnet and regtest with coin type 1',
    () async {
      final metadata = _Metadata();
      final values = _Values();
      final rows = [
        for (final network in [
          Network.bitcoinMainnet,
          Network.bitcoinTestnet,
          Network.bitcoinRegtest,
        ])
          _row(network),
      ];
      when(metadata.fetchAll).thenAnswer((_) async => rows);
      registerFallbackValue(
        WalletKey(id: 'test', network: BitcoinNetwork.mainnet),
      );
      when(() => values.getBalance(key: any(named: 'key')))
          .thenThrow(StateError('not initialized'));
      final repository = WalletRepository(
        walletMetadataDatasource: metadata,
        wallet: (_) async => throw StateError('no native access expected'),
        walletValuesDatasource: values,
        synchronize: (
          _, {
          discover = false,
          allowInitialScan = true,
          reason = SyncReason.auto,
        }) async {},
        isSyncing: ({walletId}) => false,
        syncStarted: const Stream.empty(),
        syncFinished: const Stream.empty(),
        electrumSyncResultStream: const Stream.empty(),
      );
      for (final (environment, expected) in [
        (Environment.mainnet, Network.bitcoinMainnet),
        (Environment.testnet, Network.bitcoinTestnet),
        (Environment.regtest, Network.bitcoinRegtest),
      ]) {
        final result = await repository.getWallets(environment: environment);
        expect(result, isA<Ok>());
        final wallets = (result as Ok).value as List<Wallet>;
        expect(wallets.map((wallet) => wallet.network), [expected]);
        expect(wallets.single.id, _row(expected).id);
        expect(wallets.single.origin, isNot(endsWith(':regtest')));
      }
    },
  );

  for (final code in ['bitcoinRegtest', 'unresolved']) {
    test(
      'secret protection includes $code catalog references without native reads',
      () async {
        final metadata = _Metadata();
        final values = _Values();
        final row = _row(Network.bitcoinRegtest).copyWith(networkCode: code);
        when(metadata.fetchAll).thenAnswer((_) async => [row]);
        final repository = WalletRepository(
          walletMetadataDatasource: metadata,
          wallet: (_) async => throw StateError('no native access expected'),
          walletValuesDatasource: values,
          synchronize: (
            _, {
            discover = false,
            allowInitialScan = true,
            reason = SyncReason.auto,
          }) async {},
          isSyncing: ({walletId}) => false,
          syncStarted: const Stream.empty(),
          syncFinished: const Stream.empty(),
          electrumSyncResultStream: const Stream.empty(),
        );
        final result = await repository.hasSecretReference(
          Fingerprint('73c5da0a'),
        );
        expect(result.fold((value) => value, (_) => false), true);
        when(metadata.fetchAll)
            .thenAnswer((_) async => [row.copyWith(signer: Signer.none)]);
        final watchOnly = await repository.hasSecretReference(
          Fingerprint('73c5da0a'),
        );
        expect(watchOnly.fold((value) => value, (_) => true), false);
        verifyZeroInteractions(values);
      },
    );
  }
}
