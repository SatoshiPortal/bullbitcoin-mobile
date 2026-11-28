import 'package:primitives/primitives.dart' show UnsupportedNetworkException;
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:sync/write.dart'
    show ElectrumSync, ForegroundWalletSynchronization, nativeWalletStoragePath;
import 'package:sync/storage.dart' show SyncWalletValuesDatasource;
import 'package:sync/sync.dart'
    show
        SyncFailure,
        SyncNotFoundFailure,
        WalletConnection,
        WalletConnectionPort,
        WalletKey;
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, Err, Ok, Result;
import 'package:primitives/primitives.dart' as primitives show Network;
import 'package:preferences/preferences.dart';
import 'package:legacy_storage/app_database.dart' show Signer;
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/wallet_registrations.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Metadata extends Mock implements WalletRegistrations {}

class _Values extends Mock implements SyncWalletValuesDatasource {}

class _Offline implements WalletConnectionPort {
  @override
  Future<Result<T, SyncFailure>> run<T>({
    required primitives.Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) => throw StateError('A catalog read must not sync');
}

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

Future<T> passthroughSessionJoin<T>(Future<T> Function() read) => read();

void main() {
  final synchronization = ForegroundWalletSynchronization(
    ElectrumSync(
      connections: _Offline(),
      documentsDirectory: () async => '/nonexistent',
      readRevision: (_) async => const Err(SyncNotFoundFailure()),
    ),
  );

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
        walletRegistrations: metadata,
        session: passthroughSessionJoin,
        walletValuesDatasource: values,
        synchronization: synchronization,
        syncStarted: const Stream<String>.empty(),
        syncFinished: const Stream<String>.empty(),
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

  test('native storage keeps regtest and testnet identities distinct', () {
    final regtest = _row(Network.bitcoinRegtest);
    final testnet = _row(Network.bitcoinTestnet);
    final regtestKey = WalletKey(
      id: regtest.id,
      network: regtest.network.shared,
    );
    final testnetKey = WalletKey(
      id: testnet.id,
      network: testnet.network.shared,
    );
    expect(regtestKey.network, BitcoinNetwork.regtest);
    expect(
      nativeWalletStoragePath('/wallets', regtestKey),
      isNot(nativeWalletStoragePath('/wallets', testnetKey)),
    );
    expect(
      Network.bitcoinRegtest.requireHistoricalTestnet,
      throwsA(isA<UnsupportedNetworkException>()),
    );
    expect(
      Network.liquidRegtest.requireHistoricalTestnet,
      throwsA(isA<UnsupportedNetworkException>()),
    );
  });
}
