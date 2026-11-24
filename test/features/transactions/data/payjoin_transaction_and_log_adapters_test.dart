import 'package:bull_payjoin/setup.dart';
import 'package:primitives/primitives.dart' hide Network;

import 'package:sync/sync.dart'
    show
        SyncCompletion,
        SyncConnectionFailure,
        SyncFailure,
        SyncMode,
        SyncTransactionTarget,
        WalletKey;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:transactions/testing.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLogger extends Mock implements Logger {}

class _Inventory extends Mock implements WalletInventory {}

abstract interface class _Synchronization {
  Future<Result<void, SyncFailure>> execute(WalletKey key);
}

abstract interface class _TargetedSynchronization {
  Future<Result<SyncCompletion, SyncFailure>> executeTargeted(
    WalletKey key,
    List<SyncTransactionTarget> targets,
  );
}

class _MockSynchronization extends Mock implements _Synchronization {}

class _MockTargetedSynchronization extends Mock
    implements _TargetedSynchronization {}

class _MockTransactions extends Mock implements Transactions {}

const _walletId = 'wallet';
const _txId =
    'bb71279aa030b144a12329126f0b44e6954225834d3dafaab6328bfd48939325';
const _otherTxId =
    'aa71279aa030b144a12329126f0b44e6954225834d3dafaab6328bfd48939325';
const _previousTxId =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _script = [0x00, 0x14, 1, 2, 3];
const _otherScript = [0x00, 0x14, 9, 8, 7];

void main() {
  late _Inventory inventory;
  late _MockSynchronization synchronization;
  late _MockTargetedSynchronization targeted;
  late _MockTransactions transactions;
  late AppPayjoinTransactionAdapter adapter;
  final key = WalletKey(id: _walletId, network: BitcoinNetwork.testnet);

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
    registerFallbackValue(<SyncTransactionTarget>[]);
    registerFallbackValue(key);
  });

  setUp(() {
    inventory = _Inventory();
    synchronization = _MockSynchronization();
    targeted = _MockTargetedSynchronization();
    when(() => inventory.readWallet(_walletId)).thenAnswer(
      (_) async =>
          Ok(walletRegistrationForTesting(id: _walletId, network: key.network)),
    );
    when(() => synchronization.execute(key))
        .thenAnswer((_) async => const Ok(null));
    transactions = _MockTransactions();
    adapter = AppPayjoinTransactionAdapter(
      inventory,
      transactions,
      synchronize: synchronization.execute,
      synchronizeTargeted: targeted.executeTargeted,
      finished: const Stream.empty(),
      protectSpend: (_, _) async => false,
      reconcileDelay: Duration.zero,
    );

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

  PayjoinTransaction candidate({
    String txid = _txId,
    List<List<int>> scripts = const [],
    List<Outpoint> inputs = const [],
  }) => PayjoinTransaction(
    txid: txid,
    inputs: inputs,
    outputs: [
      for (final script in scripts)
        PayjoinTransactionOutput(
          value: Sats.fromInt(1000),
          scriptPubkey: Uint8List.fromList(script),
        ),
    ],
  );

  void stubPass(SyncCompletion completion) =>
      when(() => targeted.executeTargeted(any(), any()))
          .thenAnswer((_) async => Ok(completion));

  List<SyncTransactionTarget> capturedTargets() {
    final captured = verify(
      () => targeted.executeTargeted(captureAny(), captureAny()),
    ).captured;
    expect(
      captured.first,
      key,
      reason: 'a targeted pass names the wallet it settles',
    );
    return captured.last as List<SyncTransactionTarget>;
  }

  test('answers a local read from the wallet alone', () async {
    when(() => transactions.getWalletTransaction(_txId, walletId: _walletId))
        .thenAnswer((_) async => Ok(_transaction()));

    final answers = await adapter.transactionsPresence(
      walletId: _walletId,
      transactions: [candidate()],
    );

    expect(answers, {_txId: true});
    verifyNever(() => targeted.executeTargeted(any(), any()));
    verifyNever(() => synchronization.execute(key));
    verifyNever(
      () => transactions.getWalletTransaction(
        _txId,
        walletId: _walletId,
        sync: true,
      ),
    );
  });

  test('answers a local miss as absent without syncing', () async {
    final answers = await adapter.transactionsPresence(
      walletId: _walletId,
      transactions: [candidate()],
    );

    expect(answers, {_txId: false});
    verifyNever(() => targeted.executeTargeted(any(), any()));
    verifyNever(() => synchronization.execute(key));
    verifyNever(
      () => transactions.getWalletTransaction(
        _txId,
        walletId: _walletId,
        sync: true,
      ),
    );
  });

  test('judges every candidate in one targeted pass', () async {
    stubPass(
      const SyncCompletion(
        SyncMode.targeted,
        Duration.zero,
        visibleTransactionIds: {_txId},
        coveredTransactionIds: {_txId, _otherTxId},
      ),
    );
    when(() => transactions.getWalletTransaction(_txId, walletId: _walletId))
        .thenAnswer((_) async => Ok(_transaction()));

    final answers = await adapter.transactionsPresence(
      walletId: _walletId,
      transactions: [
        candidate(scripts: [_script], inputs: [(txId: _previousTxId, vout: 1)]),
        candidate(txid: _otherTxId, scripts: [_otherScript]),
      ],
      refresh: true,
    );

    expect(answers, {_txId: true, _otherTxId: false});
    final targets = capturedTargets();
    expect(targets.map((target) => target.txid), [_txId, _otherTxId]);
    expect(targets.first.outputScripts, [Uint8List.fromList(_script)]);
    expect(targets.first.spentOutpoints, [(txId: _previousTxId, vout: 1)]);
    expect(targets.last.outputScripts, [Uint8List.fromList(_otherScript)]);
    // The wallet catches up in the background.
    await pumpEventQueue();
    verify(() => synchronization.execute(key)).called(1);
  });

  test('answers only candidates the pass covered, never the others', () async {
    stubPass(
      const SyncCompletion(
        SyncMode.targeted,
        Duration.zero,
        visibleTransactionIds: {},
        coveredTransactionIds: {_txId},
      ),
    );

    final answers = await adapter.transactionsPresence(
      walletId: _walletId,
      transactions: [
        candidate(scripts: const [_script]),
        candidate(txid: _otherTxId, scripts: const [_otherScript]),
      ],
      refresh: true,
    );

    expect(answers, {
      _txId: false,
      _otherTxId: null,
    }, reason: 'only a covered target may be answered, absent included');
    verifyNever(() => synchronization.execute(key));
  });

  test('answers a covered target the pass saw as visible', () async {
    stubPass(
      const SyncCompletion(
        SyncMode.targeted,
        Duration.zero,
        visibleTransactionIds: {_txId},
        coveredTransactionIds: {_txId},
      ),
    );
    when(() => transactions.getWalletTransaction(_txId, walletId: _walletId))
        .thenAnswer((_) async => Ok(_transaction()));

    final answers = await adapter.transactionsPresence(
      walletId: _walletId,
      transactions: [
        candidate(scripts: const [_script]),
        candidate(txid: _otherTxId, scripts: const [_otherScript]),
      ],
      refresh: true,
    );

    expect(answers, {_txId: true, _otherTxId: null});
  });

  test('a malformed candidate is unknown without blocking its peers', () async {
    const malformedTxId = 'not-a-transaction-id';
    stubPass(
      const SyncCompletion(
        SyncMode.targeted,
        Duration.zero,
        visibleTransactionIds: {},
        coveredTransactionIds: {_otherTxId},
      ),
    );

    final answers = await adapter.transactionsPresence(
      walletId: _walletId,
      transactions: [
        candidate(txid: malformedTxId, scripts: const [_script]),
        candidate(inputs: const [(txId: 'bad-outpoint', vout: 0)]),
        candidate(txid: _otherTxId, scripts: const [_otherScript]),
      ],
      refresh: true,
    );

    expect(answers, {malformedTxId: null, _txId: null, _otherTxId: false});
    expect(capturedTargets().map((target) => target.txid), [
      _otherTxId,
    ], reason: 'a malformed candidate is dropped, its valid peer still syncs');
  });

  test('a completion that covered nothing answers nothing', () async {
    for (final completion in [
      const SyncCompletion(SyncMode.targeted, Duration.zero),
      const SyncCompletion(
        SyncMode.targeted,
        Duration.zero,
        visibleTransactionIds: {_txId},
      ),
      const SyncCompletion(
        SyncMode.targeted,
        Duration.zero,
        coveredTransactionIds: {_txId},
      ),
    ]) {
      stubPass(completion);

      final answers = await adapter.transactionsPresence(
        walletId: _walletId,
        transactions: [
          candidate(scripts: const [_script]),
        ],
        refresh: true,
      );

      expect(answers, {_txId: null});
      await pumpEventQueue();
      verifyNever(() => synchronization.execute(key));
    }
  });

  test('answers a failed pass as unknown, never as absent', () async {
    when(() => targeted.executeTargeted(any(), any()))
        .thenAnswer((_) async => const Err(SyncConnectionFailure()));

    final answers = await adapter.transactionsPresence(
      walletId: _walletId,
      transactions: [
        candidate(scripts: const [_script]),
      ],
      refresh: true,
    );

    expect(answers, {_txId: null});
    await pumpEventQueue();
    verifyNever(() => synchronization.execute(key));
  });

  test('answers an unavailable pass as unknown, never as absent', () async {
    when(() => targeted.executeTargeted(any(), any()))
        .thenAnswer((_) async => throw Exception('pass unavailable'));

    final answers = await adapter.transactionsPresence(
      walletId: _walletId,
      transactions: [
        candidate(scripts: const [_script]),
      ],
      refresh: true,
    );

    expect(answers, {_txId: null});
    await pumpEventQueue();
    verifyNever(() => synchronization.execute(key));
  });

  test('refuses a Liquid wallet before any pass', () async {
    when(() => inventory.readWallet(_walletId)).thenAnswer(
      (_) async => Ok(
        walletRegistrationForTesting(
          id: _walletId,
          network: LiquidNetwork.testnet,
        ),
      ),
    );

    await expectLater(
      adapter.transactionsPresence(
        walletId: _walletId,
        transactions: [
          candidate(scripts: const [_script]),
        ],
        refresh: true,
      ),
      throwsException,
    );
    verifyNever(() => targeted.executeTargeted(any(), any()));
  });

  test('reconciles only the ids the pass proved visible', () async {
    stubPass(
      const SyncCompletion(
        SyncMode.targeted,
        Duration.zero,
        visibleTransactionIds: {_txId},
        coveredTransactionIds: {_txId, _otherTxId},
      ),
    );
    when(() => transactions.getWalletTransaction(_txId, walletId: _walletId))
        .thenAnswer((_) async => Ok(_transaction()));

    await adapter.transactionsPresence(
      walletId: _walletId,
      transactions: [
        candidate(scripts: const [_script]),
        candidate(txid: _otherTxId, scripts: const [_otherScript]),
      ],
      refresh: true,
    );
    await pumpEventQueue();

    verify(() => synchronization.execute(key)).called(1);
    verify(() => transactions.getWalletTransaction(_txId, walletId: _walletId))
        .called(1);
    verifyNever(
      () => transactions.getWalletTransaction(_otherTxId, walletId: _walletId),
    );
  });

  test('sync completion requires admission for the exact account', () async {
    final finished = StreamController<WalletKey>();
    final adapter = AppPayjoinTransactionAdapter(
      inventory,
      transactions,
      synchronize: synchronization.execute,
      synchronizeTargeted: targeted.executeTargeted,
      finished: finished.stream,
      protectSpend: (_, _) async => false,
    );
    final completions = <Object?>[];
    final subscription = adapter
        .watchWallet(_walletId)
        .listen((_) => completions.add(null));
    addTearDown(subscription.cancel);
    addTearDown(finished.close);

    when(() => inventory.readWallet(_walletId))
        .thenAnswer((_) async => const Err(KeystoreLockedFailure()));
    finished.add(key);
    await pumpEventQueue();
    expect(completions, isEmpty);

    when(() => inventory.readWallet(_walletId)).thenAnswer(
      (_) async =>
          Ok(walletRegistrationForTesting(id: _walletId, network: key.network)),
    );
    finished.add(WalletKey(id: _walletId, network: BitcoinNetwork.mainnet));
    finished.add(key);
    await pumpEventQueue();
    expect(completions, hasLength(1));
  });

  test('never answers a candidate it cannot describe', () async {
    stubPass(
      const SyncCompletion(
        SyncMode.targeted,
        Duration.zero,
        visibleTransactionIds: {},
        coveredTransactionIds: {_txId},
      ),
    );

    final answers = await adapter.transactionsPresence(
      walletId: _walletId,
      transactions: [
        PayjoinTransaction.idOnly('undescribed-tx'),
        candidate(scripts: const [_script]),
      ],
      refresh: true,
    );

    expect(answers, {'undescribed-tx': null, _txId: false});
    expect(capturedTargets().map((target) => target.txid), [_txId]);
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
