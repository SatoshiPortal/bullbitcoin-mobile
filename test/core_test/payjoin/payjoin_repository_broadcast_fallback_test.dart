import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/electrum/domain/electrum_fallback_runner.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/local_payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/pdk_payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/models/payjoin_model.dart';
import 'package:bb_mobile/core/payjoin/data/repository/payjoin_repository_impl.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/unconfirmed_bitcoin_transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLocalPayjoinDatasource extends Mock
    implements LocalPayjoinDatasource {}

class _MockPdkPayjoinDatasource extends Mock implements PdkPayjoinDatasource {}

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _MockSeedDatasource extends Mock implements SeedDatasource {}

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _MockBdkBitcoinBlockchainDatasource extends Mock
    implements BdkBitcoinBlockchainDatasource {}

class _MockUnconfirmedBitcoinTransactionRepository extends Mock
    implements UnconfirmedBitcoinTransactionRepository {}

/// Runs the real [runElectrumFallback] over two fixed servers — enough to
/// prove that [PayjoinRepositoryImpl]'s broadcast calls pass the shared
/// broadcast-error classifier through as `isTransient`, without pulling in
/// the real server-resolution adapter and its repositories.
class _FakeTwoServerPort implements ElectrumServersPort {
  final tried = <String>[];

  static const _servers = [
    ElectrumConnection(
      url: 'server-a',
      retry: 1,
      timeout: 1,
      stopGap: 1,
      validateDomain: false,
      isCustom: false,
    ),
    ElectrumConnection(
      url: 'server-b',
      retry: 1,
      timeout: 1,
      stopGap: 1,
      validateDomain: false,
      isCustom: false,
    ),
  ];

  @override
  Future<T> runWithFallback<T>({
    required ElectrumServerNetwork network,
    required Future<T> Function(ElectrumConnection connection) operation,
    bool Function(Object error)? isTransient,
  }) {
    return runElectrumFallback<ElectrumConnection, T>(
      servers: _servers,
      urlOf: (c) => c.url,
      isCustomOf: (c) => c.isCustom,
      operation: (c) {
        tried.add(c.url);
        return operation(c);
      },
      isTransient: isTransient,
    );
  }
}

void main() {
  late _MockLocalPayjoinDatasource localPayjoinDatasource;
  late _MockPdkPayjoinDatasource pdkPayjoinDatasource;
  late _MockWalletMetadataDatasource walletMetadataDatasource;
  late _MockSeedDatasource seedDatasource;
  late _MockBdkWalletDatasource bdkWalletDatasource;
  late _MockBdkBitcoinBlockchainDatasource blockchainDatasource;
  late _FakeTwoServerPort serversPort;
  late _MockUnconfirmedBitcoinTransactionRepository unconfirmedBitcoinTx;
  late PayjoinRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(
      const ElectrumConnection(
        url: 'fallback',
        retry: 1,
        timeout: 1,
        stopGap: 1,
        validateDomain: false,
        isCustom: false,
      ),
    );
    registerFallbackValue(
      PayjoinModel.receiver(
        id: 'fallback',
        address: 'bcrt1qaddress',
        isTestnet: true,
        receiver: 'receiver',
        walletId: 'wallet-1',
        pjUri: 'bitcoin:bcrt1qaddress?pj=https://example.com',
        maxFeeRateSatPerVb: BigInt.zero,
        createdAt: 0,
        expireAfterSec: 3600,
      ),
    );
  });

  Payjoin receiverPayjoin() => Payjoin.receiver(
    id: 'pj-1',
    isTestnet: true,
    walletId: 'wallet-1',
    pjUri: 'bitcoin:bcrt1qaddress?pj=https://example.com',
    createdAt: DateTime.now(),
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
    originalTxBytes: Uint8List.fromList([1, 2, 3]),
  );

  setUp(() {
    localPayjoinDatasource = _MockLocalPayjoinDatasource();
    pdkPayjoinDatasource = _MockPdkPayjoinDatasource();
    walletMetadataDatasource = _MockWalletMetadataDatasource();
    seedDatasource = _MockSeedDatasource();
    bdkWalletDatasource = _MockBdkWalletDatasource();
    blockchainDatasource = _MockBdkBitcoinBlockchainDatasource();
    serversPort = _FakeTwoServerPort();
    unconfirmedBitcoinTx = _MockUnconfirmedBitcoinTransactionRepository();

    when(
      () => pdkPayjoinDatasource.requestsForReceivers,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => pdkPayjoinDatasource.proposalsForSenders,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => pdkPayjoinDatasource.expiredPayjoins,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => localPayjoinDatasource.fetchAll(onlyUnfinished: true),
    ).thenAnswer((_) async => <PayjoinModel>[]);

    repository = PayjoinRepositoryImpl(
      localPayjoinDatasource: localPayjoinDatasource,
      pdkPayjoinDatasource: pdkPayjoinDatasource,
      walletMetadataDatasource: walletMetadataDatasource,
      seedDatasource: seedDatasource,
      bdkWalletDatasource: bdkWalletDatasource,
      blockchainDatasource: blockchainDatasource,
      serversPort: serversPort,
      unconfirmedBitcoinTransactionRepository: unconfirmedBitcoinTx,
    );
  });

  group(
    'tryBroadcastOriginalTransaction — broadcast fallback classification',
    () {
      test('a permanent mempool rejection from the first server is not retried '
          'on the second server', () async {
        when(
          () => blockchainDatasource.broadcastTransaction(
            any(),
            connection: any(named: 'connection'),
          ),
        ).thenThrow(Exception('missingorspent (code 64)'));

        // tryBroadcastOriginalTransaction never rethrows — it logs and
        // returns null — so the observable effect of "not retried" is the
        // fake port's `tried` list, not a thrown exception.
        final result = await repository.tryBroadcastOriginalTransaction(
          receiverPayjoin(),
        );

        expect(result, isNull);
        expect(serversPort.tried, ['server-a']);
      });

      test('a transient error from the first server falls back to the second, '
          'which then succeeds', () async {
        when(
          () => blockchainDatasource.broadcastTransaction(
            any(),
            connection: any(named: 'connection'),
          ),
        ).thenAnswer((invocation) async {
          final connection =
              invocation.namedArguments[#connection] as ElectrumConnection;
          if (connection.url == 'server-a') {
            throw Exception('connection refused');
          }
          return 'txid-success';
        });
        final storedModel =
            PayjoinModel.receiver(
                  id: 'pj-1',
                  address: 'bcrt1qaddress',
                  isTestnet: true,
                  receiver: 'receiver',
                  walletId: 'wallet-1',
                  pjUri: 'bitcoin:bcrt1qaddress?pj=https://example.com',
                  maxFeeRateSatPerVb: BigInt.from(10000),
                  createdAt: 0,
                  expireAfterSec: 3600,
                )
                as PayjoinReceiverModel;
        when(
          () => localPayjoinDatasource.fetchReceiver('pj-1'),
        ).thenAnswer((_) async => storedModel);
        when(
          () => localPayjoinDatasource.update(any()),
        ).thenAnswer((_) async {});

        final result = await repository.tryBroadcastOriginalTransaction(
          receiverPayjoin(),
        );

        expect(result, isNotNull);
        expect(serversPort.tried, ['server-a', 'server-b']);
      });
    },
  );
}
