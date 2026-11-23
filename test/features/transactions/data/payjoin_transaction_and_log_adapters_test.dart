import 'package:bull_payjoin/setup.dart';
import 'package:primitives/primitives.dart' hide Network;

import '../../../scripted_wallet_connections.dart';

import 'package:sync/sync.dart'
    show SyncConnectionFailure, SyncUnrecognizedReplyFailure;

import 'dart:io';

import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:transactions/testing.dart';
import 'package:transactions/transactions.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/data/payjoin_transaction_adapter.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLogger extends Mock implements Logger {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockTransactions extends Mock implements Transactions {}

class _MockWallet extends Mock implements Wallet {}

const _walletId = 'wallet';
const _txId =
    'bb71279aa030b144a12329126f0b44e6954225834d3dafaab6328bfd48939325';

void main() {
  late _MockWalletRepository wallets;
  late _MockTransactions transactions;
  late ScriptedWalletConnections servers;
  late _MockWallet wallet;
  late AppPayjoinTransactionAdapter adapter;

  test('poll state codes survive the persisted host adapter', () async {
    final directory = await Directory.systemTemp.createTemp(
      'payjoin-poll-log-',
    );
    log = Logger.replace(directory: directory);
    addTearDown(() async {
      await log.flush();
      await directory.delete(recursive: true);
    });
    const adapter = AppPayjoinLogAdapter();
    for (final code in [
      PayjoinLogCode.pollReplayFailed,
      PayjoinLogCode.pollRequestFailed,
      PayjoinLogCode.pollParseFailed,
      PayjoinLogCode.pollRecovered,
    ]) {
      adapter.write(
        PayjoinLogEvent(
          level: code == PayjoinLogCode.pollRecovered
              ? PayjoinLogLevel.fine
              : PayjoinLogLevel.warning,
          code: code,
          role: PayjoinLogRole.receiver,
        ),
      );
    }
    expect((await log.readLogs()).map((row) => row.split('\t')[2]), [
      'Payjoin receiver pollReplayFailed: Poll failed stage=replay',
      'Payjoin receiver pollRequestFailed: Poll failed stage=request',
      'Payjoin receiver pollParseFailed: Poll failed stage=parse',
      'Payjoin receiver pollRecovered: Poll state recovered',
    ]);
  });

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() {
    wallets = _MockWalletRepository();
    transactions = _MockTransactions();
    servers = ScriptedWalletConnections();
    adapter = AppPayjoinTransactionAdapter(
      wallets,
      transactions,
      servers,
      reconcileDelay: Duration.zero,
    );

    wallet = _MockWallet();
    when(() => wallet.network).thenReturn(Network.bitcoinTestnet);
    when(() => wallets.getWallet(_walletId, sync: any(named: 'sync')))
        .thenAnswer((_) async => Ok(wallet));
    when(() => transactions.getWalletTransaction(_txId, walletId: _walletId))
        .thenAnswer((_) async => const Ok(null));
  });

  test('structured events preserve the exported TSV contract', () async {
    final previousLogger = log;
    final directory = await Directory.systemTemp.createTemp('payjoin_tsv');
    addTearDown(() async {
      await log.flush();
      log = previousLogger;
      await directory.delete(recursive: true);
    });
    log = Logger.replace(directory: directory);
    const adapter = AppPayjoinLogAdapter();
    const sessionRef = '0123456789abcdef';
    final request = RequestOptions(path: 'https://private-relay/x');

    final events = [
      PayjoinLogEvent(
        level: PayjoinLogLevel.info,
        code: PayjoinLogCode.lifecycle,
        role: PayjoinLogRole.sender,
        sessionRef: sessionRef,
      ),
      PayjoinLogEvent(
        level: PayjoinLogLevel.fine,
        code: PayjoinLogCode.sessionStarted,
        role: PayjoinLogRole.sender,
        sessionRef: sessionRef,
      ),
      PayjoinLogEvent(
        level: PayjoinLogLevel.fine,
        code: PayjoinLogCode.proposalSent,
        role: PayjoinLogRole.receiver,
        sessionRef: sessionRef,
      ),
      PayjoinLogEvent(
        level: PayjoinLogLevel.warning,
        code: PayjoinLogCode.relayFailure,
        role: PayjoinLogRole.sender,
        sessionRef: sessionRef,
        error: DioException(
          requestOptions: request,
          response: Response<void>(requestOptions: request, statusCode: 403),
          type: DioExceptionType.badResponse,
        ),
      ),
      PayjoinLogEvent(
        level: PayjoinLogLevel.severe,
        code: PayjoinLogCode.storageFailure,
        role: PayjoinLogRole.receiver,
        sessionRef: sessionRef,
        error: Exception('bitcoin:private-address?pj=https://private-relay'),
        trace: StackTrace.fromString('payjoin-trace'),
      ),
    ];
    for (final event in events) {
      adapter.write(event);
    }
    expect(events.map((event) => event.sessionRef), everyElement(sessionRef));

    final rows = (await log.readLogs())
        .map((line) => line.split('\t'))
        .toList();
    for (final row in rows) {
      expect(row, hasLength(5));
      expect(DateTime.tryParse(row.first), isNotNull);
    }
    expect(rows.map((row) => row.skip(1).toList()).toList(), [
      [
        'FINE',
        'Payjoin sender 0123456 sessionStarted: Session created and stored',
        '',
        '',
      ],
      [
        'FINE',
        'Payjoin receiver 0123456 proposalSent: Payjoin proposal sent to the sender',
        '',
        '',
      ],
      [
        'WARNING',
        'Payjoin sender 0123456 relayFailure: Payjoin directory request failed '
            'through every OHTTP relay cause=transport_badResponse(403)',
        '',
        '',
      ],
      [
        'SEVERE',
        'Payjoin receiver 0123456 storageFailure: Payjoin storage failed '
            'cause=operation',
        'storageFailure',
        'payjoin-trace',
      ],
    ]);
  });

  test('session milestones reach the exported log file', () async {
    final previousLogger = log;
    final directory = await Directory.systemTemp.createTemp('payjoin_logs');
    addTearDown(() async {
      log = previousLogger;
      await directory.delete(recursive: true);
    });
    log = Logger.replace(directory: directory);
    await log.ensureLogsExist(writeDiagnosticContext: false);
    const adapter = AppPayjoinLogAdapter();

    adapter.write(
      PayjoinLogEvent(
        level: PayjoinLogLevel.fine,
        code: PayjoinLogCode.sessionStarted,
        sessionRef: '0123456789abcdef',
      ),
    );

    final lines = await log.readLogs();
    expect(
      lines.where((line) => line.contains('0123456')),
      hasLength(1),
      reason: 'an exported log must show how a payjoin attempt progressed',
    );
  });

  test(
    'INFO events stay out of the export even with a milestone code',
    () async {
      final previousLogger = log;
      final directory = await Directory.systemTemp.createTemp('payjoin_info');
      addTearDown(() async {
        log = previousLogger;
        await directory.delete(recursive: true);
      });
      log = Logger.replace(directory: directory);
      await log.ensureLogsExist(writeDiagnosticContext: false);

      const AppPayjoinLogAdapter().write(
        PayjoinLogEvent(
          level: PayjoinLogLevel.info,
          code: PayjoinLogCode.sessionStarted,
          role: PayjoinLogRole.sender,
          sessionRef: '0123456789abcdef',
        ),
      );

      expect(
        (await log.readLogs()).where((line) => line.contains('0123456')),
        isEmpty,
        reason:
            'persistence follows the wallet log level, never the event code',
      );
    },
  );

  test('polling chatter stays out of the exported log file', () async {
    final previousLogger = log;
    final directory = await Directory.systemTemp.createTemp('payjoin_logs');
    addTearDown(() async {
      log = previousLogger;
      await directory.delete(recursive: true);
    });
    log = Logger.replace(directory: directory);
    await log.ensureLogsExist(writeDiagnosticContext: false);
    const adapter = AppPayjoinLogAdapter();

    adapter.write(
      PayjoinLogEvent(
        level: PayjoinLogLevel.info,
        code: PayjoinLogCode.lifecycle,
        sessionRef: '0123456789abcdef',
      ),
    );

    expect(
      (await log.readLogs()).where((line) => line.contains('Payjoin')),
      isEmpty,
    );
  });

  test('a milestone names its side, step and session', () {
    final previousLogger = log;
    final logger = _MockLogger();
    log = logger;
    addTearDown(() => log = previousLogger);

    const AppPayjoinLogAdapter().write(
      PayjoinLogEvent(
        level: PayjoinLogLevel.fine,
        code: PayjoinLogCode.proposalReceived,
        role: PayjoinLogRole.sender,
        sessionRef: '0123456789abcdef',
      ),
    );

    expect(
      verify(() => logger.fine(captureAny())).captured.single,
      'Payjoin sender 0123456 proposalReceived: Payjoin proposal received from the receiver',
    );
  });

  test('a relay failure keeps its transport kind but not its URL', () {
    final previousLogger = log;
    final logger = _MockLogger();
    log = logger;
    addTearDown(() => log = previousLogger);

    const AppPayjoinLogAdapter().write(
      PayjoinLogEvent(
        level: PayjoinLogLevel.warning,
        code: PayjoinLogCode.relayFailure,
        role: PayjoinLogRole.sender,
        error: DioException.connectionError(
          requestOptions: RequestOptions(path: 'https://private-relay/x'),
          reason: 'Failed host lookup: private-relay',
        ),
      ),
    );

    final warning = verify(() => logger.warning(captureAny())).captured.single;
    expect(warning, contains('cause=transport_connectionError'));
    expect(warning, isNot(contains('private-relay')));
  });

  test('a server failure retains its transport kind without its host', () {
    final previousLogger = log;
    final logger = _MockLogger();
    log = logger;
    addTearDown(() => log = previousLogger);

    const AppPayjoinLogAdapter().write(
      PayjoinLogEvent(
        level: PayjoinLogLevel.warning,
        code: PayjoinLogCode.relayUnreachable,
        server: Uri.https('pj.bullbitcoin.com'),
        error: DioException.connectionError(
          requestOptions: RequestOptions(path: 'https://pj.bullbitcoin.com/x'),
          reason: 'Failed host lookup',
        ),
      ),
    );

    expect(
      verify(() => logger.warning(captureAny())).captured.single,
      'Payjoin relayUnreachable: OHTTP relay did not answer, trying another cause=transport_connectionError',
    );
  });

  test('a relay rejection does not imply an unreachable directory', () {
    final previousLogger = log;
    final logger = _MockLogger();
    log = logger;
    addTearDown(() => log = previousLogger);
    final request = RequestOptions(path: 'https://private-relay/x');

    const AppPayjoinLogAdapter().write(
      PayjoinLogEvent(
        level: PayjoinLogLevel.warning,
        code: PayjoinLogCode.relayFailure,
        error: DioException(
          requestOptions: request,
          response: Response<void>(requestOptions: request, statusCode: 403),
          type: DioExceptionType.badResponse,
        ),
      ),
    );

    final warning = verify(() => logger.warning(captureAny())).captured.single;
    expect(warning, contains('cause=transport_badResponse(403)'));
    expect(warning, isNot(contains('unreachable')));
    expect(warning, isNot(contains('private-relay')));
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
    expect(
      warning,
      'Payjoin 0123456 watchFailure: Transaction watch failed cause=operation',
    );
    final errors = verify(
      () => logger.severe(
        message: captureAny(named: 'message'),
        error: captureAny(named: 'error'),
        trace: any(named: 'trace'),
      ),
    ).captured;
    expect(errors, unorderedEquals([warning, 'watchFailure']));
    final reportedError = errors
        .firstWhere((value) => value == 'watchFailure')
        .toString();
    expect(reportedError, isNot(contains('private-address')));
    expect(reportedError, isNot(contains('private-server')));
    expect(reportedError, isNot(contains('raw-transaction-id')));
    expect(reportedError, isNot(contains('0123456')));
  });

  test('answers from the wallet when no refresh is asked', () async {
    when(() => transactions.getWalletTransaction(_txId, walletId: _walletId))
        .thenAnswer((_) async => Ok(_transaction()));

    final visible = await adapter.isTransactionVisible(
      walletId: _walletId,
      transactionId: _txId,
    );

    expect(visible, isTrue);
    expect(servers.networks, isEmpty);
  });

  test('a refresh trusts the server over a pending wallet copy', () async {
    when(() => transactions.getWalletTransaction(_txId, walletId: _walletId))
        .thenAnswer((_) async => Ok(_transaction()));
    servers.reply = () => const Ok(false);

    final visible = await adapter.isTransactionVisible(
      walletId: _walletId,
      transactionId: _txId,
      refresh: true,
    );

    expect(visible, isFalse);
    expect(servers.networks, [BitcoinNetwork.testnet]);
  });

  test('stays local when no refresh is asked', () async {
    final visible = await adapter.isTransactionVisible(
      walletId: _walletId,
      transactionId: _txId,
    );

    expect(visible, isFalse);
    expect(servers.networks, isEmpty);
  });

  test('asks the server for the one transaction instead of syncing', () async {
    servers.reply = () => const Ok(true);
    var synced = false;
    when(() => wallets.getWallet(_walletId, sync: true)).thenAnswer((_) async {
      synced = true;
      return Ok(wallet);
    });
    when(() => transactions.getWalletTransaction(_txId, walletId: _walletId))
        .thenAnswer((_) async => Ok(synced ? _transaction() : null));

    final visible = await adapter.isTransactionVisible(
      walletId: _walletId,
      transactionId: _txId,
      refresh: true,
    );

    expect(visible, isTrue);
    expect(servers.networks, [BitcoinNetwork.testnet]);
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
    servers.reply = () => const Ok(true);
    var syncs = 0;
    when(() => wallets.getWallet(_walletId, sync: true)).thenAnswer((_) async {
      syncs++;
      return syncs == 1 ? const Err(WalletStorageFailure('busy')) : Ok(wallet);
    });
    // The second sync joined a pass that started before the broadcast.
    when(() => transactions.getWalletTransaction(_txId, walletId: _walletId))
        .thenAnswer((_) async => Ok(syncs >= 3 ? _transaction() : null));

    await adapter.isTransactionVisible(
      walletId: _walletId,
      transactionId: _txId,
      refresh: true,
    );
    await pumpEventQueue();

    verify(() => wallets.getWallet(_walletId, sync: true)).called(3);
  });

  test('stops reconciling after a few failed syncs', () async {
    servers.reply = () => const Ok(true);
    when(() => wallets.getWallet(_walletId, sync: true))
        .thenAnswer((_) async => const Err(WalletStorageFailure('busy')));

    await adapter.isTransactionVisible(
      walletId: _walletId,
      transactionId: _txId,
      refresh: true,
    );
    await pumpEventQueue();

    verify(() => wallets.getWallet(_walletId, sync: true)).called(3);
  });

  test('a failing wallet read does not end the reconciliation', () async {
    servers.reply = () => const Ok(true);
    when(() => wallets.getWallet(_walletId, sync: true))
        .thenAnswer((_) async => Ok(wallet));
    var reads = 0;
    when(() => transactions.getWalletTransaction(_txId, walletId: _walletId))
        .thenAnswer((_) async {
          reads++;
          if (reads == 1) return const Err(TransactionAggregationFailure());
          return Ok(_transaction());
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
    servers.reply = () => const Ok(false);

    final visible = await adapter.isTransactionVisible(
      walletId: _walletId,
      transactionId: _txId,
      refresh: true,
    );

    expect(visible, isFalse);
    verifyNever(() => wallets.getWallet(_walletId, sync: true));
  });

  for (final present in [true, false]) {
    test('falls back to a wallet sync when the reply is unclassified '
        '(transaction ${present ? 'present' : 'absent'})', () async {
      servers.reply = () => const Err(SyncUnrecognizedReplyFailure());
      when(
        () => transactions.getWalletTransaction(
          _txId,
          walletId: _walletId,
          sync: true,
        ),
      ).thenAnswer((_) async => Ok(present ? _transaction() : null));

      final visible = await adapter.isTransactionVisible(
        walletId: _walletId,
        transactionId: _txId,
        refresh: true,
      );

      expect(visible, present);
      expect(servers.retried, isEmpty);
      // An absence is only trusted after a second pass: the first sync can
      // have joined a pass that started before the broadcast.
      verify(
        () => transactions.getWalletTransaction(
          _txId,
          walletId: _walletId,
          sync: true,
        ),
      ).called(present ? 1 : 2);
      verifyNever(() => wallets.getWallet(_walletId, sync: true));
    });
  }

  test('propagates a server failure instead of answering absent', () async {
    servers.reply = () => const Err(SyncConnectionFailure());

    await expectLater(
      adapter.isTransactionVisible(
        walletId: _walletId,
        transactionId: _txId,
        refresh: true,
      ),
      throwsException,
    );
    expect(servers.retried.single, isA<SyncConnectionFailure>());
  });
}

WalletTransaction _transaction() => const WalletTransaction(
  walletId: _walletId,
  network: BitcoinNetwork.testnet,
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
