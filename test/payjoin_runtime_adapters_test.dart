import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/payjoin_runtime_adapters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockLogger extends Mock implements Logger {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockWalletTransactionRepository extends Mock
    implements WalletTransactionRepository {}

class _MockBlockchain extends Mock implements BdkBitcoinBlockchainDatasource {}

class _MockWallet extends Mock implements Wallet {}

class _FakeServers implements ElectrumServersPort {
  ElectrumServerNetwork? network;

  @override
  Future<T> runWithFallback<T>({
    required ElectrumServerNetwork network,
    required Future<T> Function(ElectrumConnection connection) operation,
    bool Function(Object error)? isTransient,
  }) {
    this.network = network;
    return operation(_connection);
  }
}

const _connection = ElectrumConnection(
  url: 'ssl://electrum.test:50002',
  retry: 0,
  timeout: 5,
  stopGap: 20,
  validateDomain: true,
  isCustom: false,
);

const _walletId = 'wallet';
const _txId =
    'bb71279aa030b144a12329126f0b44e6954225834d3dafaab6328bfd48939325';

void main() {
  late _MockWalletRepository wallets;
  late _MockWalletTransactionRepository transactions;
  late _MockBlockchain blockchain;
  late _FakeServers servers;
  late _MockWallet wallet;
  late AppPayjoinTransactionAdapter adapter;

  setUpAll(() {
    registerFallbackValue(_connection);
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() {
    wallets = _MockWalletRepository();
    transactions = _MockWalletTransactionRepository();
    blockchain = _MockBlockchain();
    servers = _FakeServers();
    adapter = AppPayjoinTransactionAdapter(
      wallets,
      transactions,
      blockchain,
      servers,
      reconcileDelay: Duration.zero,
    );

    wallet = _MockWallet();
    when(() => wallet.isTestnet).thenReturn(true);
    when(
      () => wallets.getWallet(_walletId, sync: any(named: 'sync')),
    ).thenAnswer((_) async => Ok(wallet));
    when(
      () => transactions.getWalletTransaction(_txId, walletId: _walletId),
    ).thenAnswer((_) async => null);
  });

  test('foreign warning and severe causes cannot leak payment data', () {
    final previousLogger = log;
    final logger = _MockLogger();
    log = logger;
    addTearDown(() => log = previousLogger);
    const adapter = AppPayjoinLogAdapter();
    final cause = Exception(
      'bitcoin:private-address?pj=https://private-server '
      'raw-transaction-id',
    );
    for (final level in [PayjoinLogLevel.warning, PayjoinLogLevel.severe]) {
      adapter.write(
        PayjoinLogEvent(
          level: level,
          code: PayjoinLogCode.watchFailure,
          sessionRef: '0123456789abcdef',
          error: cause,
          trace: StackTrace.current,
        ),
      );
    }
    final warning = verify(() => logger.warning(captureAny())).captured.single;
    expect(warning, 'Payjoin watchFailure 0123456789abcdef _Exception');
    final errors = verify(
      () => logger.severe(
        message: captureAny(named: 'message'),
        error: captureAny(named: 'error'),
        trace: any(named: 'trace'),
      ),
    ).captured;
    expect(errors.whereType<String>().single, warning);
    final reportedError = errors.whereType<Exception>().single.toString();
    expect(reportedError, isNot(contains('private-address')));
    expect(reportedError, isNot(contains('private-server')));
    expect(reportedError, isNot(contains('raw-transaction-id')));
    expect(reportedError, isNot(contains('0123456789abcdef')));
  });

  test('answers from the wallet when no refresh is asked', () async {
    when(
      () => transactions.getWalletTransaction(_txId, walletId: _walletId),
    ).thenAnswer((_) async => _transaction());

    final visible = await adapter.isTransactionVisible(
      walletId: _walletId,
      transactionId: _txId,
    );

    expect(visible, isTrue);
    verifyNever(
      () => blockchain.isTransactionKnown(
        any(),
        connection: any(named: 'connection'),
      ),
    );
  });

  test('a refresh trusts the server over a pending wallet copy', () async {
    when(
      () => transactions.getWalletTransaction(_txId, walletId: _walletId),
    ).thenAnswer((_) async => _transaction());
    when(
      () => blockchain.isTransactionKnown(
        _txId,
        connection: any(named: 'connection'),
      ),
    ).thenAnswer((_) async => false);

    final visible = await adapter.isTransactionVisible(
      walletId: _walletId,
      transactionId: _txId,
      refresh: true,
    );

    expect(visible, isFalse);
    verify(
      () => blockchain.isTransactionKnown(
        _txId,
        connection: any(named: 'connection'),
      ),
    ).called(1);
  });

  test('stays local when no refresh is asked', () async {
    final visible = await adapter.isTransactionVisible(
      walletId: _walletId,
      transactionId: _txId,
    );

    expect(visible, isFalse);
    verifyNever(
      () => blockchain.isTransactionKnown(
        any(),
        connection: any(named: 'connection'),
      ),
    );
  });

  test('asks the server for the one transaction instead of syncing', () async {
    when(
      () => blockchain.isTransactionKnown(
        _txId,
        connection: any(named: 'connection'),
      ),
    ).thenAnswer((_) async => true);
    var synced = false;
    when(() => wallets.getWallet(_walletId, sync: true)).thenAnswer((_) async {
      synced = true;
      return Ok(wallet);
    });
    when(
      () => transactions.getWalletTransaction(_txId, walletId: _walletId),
    ).thenAnswer((_) async => synced ? _transaction() : null);

    final visible = await adapter.isTransactionVisible(
      walletId: _walletId,
      transactionId: _txId,
      refresh: true,
    );

    expect(visible, isTrue);
    expect(servers.network, ElectrumServerNetwork.bitcoinTestnet);
    verifyNever(
      () => transactions.getWalletTransaction(
        _txId,
        walletId: _walletId,
        sync: true,
      ),
    );
    // The wallet catches up in the background.
    await pumpEventQueue();
    verify(() => wallets.getWallet(_walletId, sync: true)).called(1);
  });

  test('syncs again when the wallet fails or misses the transaction', () async {
    when(
      () => blockchain.isTransactionKnown(
        _txId,
        connection: any(named: 'connection'),
      ),
    ).thenAnswer((_) async => true);
    var syncs = 0;
    when(() => wallets.getWallet(_walletId, sync: true)).thenAnswer((_) async {
      syncs++;
      return syncs == 1 ? const Err(WalletStorageFailure('busy')) : Ok(wallet);
    });
    // The second sync joined a pass that started before the broadcast.
    when(
      () => transactions.getWalletTransaction(_txId, walletId: _walletId),
    ).thenAnswer((_) async => syncs >= 3 ? _transaction() : null);

    await adapter.isTransactionVisible(
      walletId: _walletId,
      transactionId: _txId,
      refresh: true,
    );
    await pumpEventQueue();

    verify(() => wallets.getWallet(_walletId, sync: true)).called(3);
  });

  test('stops reconciling after a few failed syncs', () async {
    when(
      () => blockchain.isTransactionKnown(
        _txId,
        connection: any(named: 'connection'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => wallets.getWallet(_walletId, sync: true),
    ).thenAnswer((_) async => const Err(WalletStorageFailure('busy')));

    await adapter.isTransactionVisible(
      walletId: _walletId,
      transactionId: _txId,
      refresh: true,
    );
    await pumpEventQueue();

    verify(() => wallets.getWallet(_walletId, sync: true)).called(3);
  });

  test('a failing wallet read does not end the reconciliation', () async {
    when(
      () => blockchain.isTransactionKnown(
        _txId,
        connection: any(named: 'connection'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => wallets.getWallet(_walletId, sync: true),
    ).thenAnswer((_) async => Ok(wallet));
    var reads = 0;
    when(
      () => transactions.getWalletTransaction(_txId, walletId: _walletId),
    ).thenAnswer((_) async {
      reads++;
      if (reads == 1) throw Exception('database locked');
      return _transaction();
    });

    await adapter.isTransactionVisible(
      walletId: _walletId,
      transactionId: _txId,
      refresh: true,
    );
    await pumpEventQueue();

    verify(() => wallets.getWallet(_walletId, sync: true)).called(2);
  });

  test('reports an unknown transaction without syncing the wallet', () async {
    when(
      () => blockchain.isTransactionKnown(
        _txId,
        connection: any(named: 'connection'),
      ),
    ).thenAnswer((_) async => false);

    final visible = await adapter.isTransactionVisible(
      walletId: _walletId,
      transactionId: _txId,
      refresh: true,
    );

    expect(visible, isFalse);
    verifyNever(() => wallets.getWallet(_walletId, sync: true));
  });

  test('propagates a server failure instead of answering absent', () async {
    when(
      () => blockchain.isTransactionKnown(
        _txId,
        connection: any(named: 'connection'),
      ),
    ).thenThrow(Exception('unreachable'));

    expect(
      adapter.isTransactionVisible(
        walletId: _walletId,
        transactionId: _txId,
        refresh: true,
      ),
      throwsException,
    );
  });
}

WalletTransaction _transaction() => const WalletTransaction(
  walletId: _walletId,
  network: Network.bitcoinTestnet,
  direction: WalletTransactionDirection.incoming,
  status: WalletTransactionStatus.pending,
  txId: _txId,
  amountSat: 20000,
  feeSat: 209,
  vsize: 208,
  inputs: [],
  outputs: [],
  isRbf: true,
);
