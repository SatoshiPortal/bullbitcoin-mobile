import 'dart:async';
import 'dart:typed_data';

import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_payjoin/src/data/local_payjoin_datasource.dart';
import 'package:bull_payjoin/src/data/payjoin_database.dart';
import 'package:bull_payjoin/src/data/payjoin_model.dart';
import 'package:bull_payjoin/src/data/payjoin_input_pair_model.dart';
import 'package:bull_payjoin/src/data/payjoin_policy_store.dart';
import 'package:bull_payjoin/src/engine/bitcoin_tx.dart';
import 'package:bull_payjoin/src/engine/payjoin.dart' as internal;
import 'package:bull_payjoin/src/engine/payjoin_engine.dart';
import 'package:bull_payjoin/src/engine/payjoin_logger.dart';
import 'package:bull_payjoin/src/engine/pdk_payjoin_datasource.dart';
import 'package:drift/native.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

class _MockPdkPayjoinDatasource extends Mock implements PdkPayjoinDatasource {}

class _MockWalletPort extends Mock implements PayjoinWalletPort {}

class _MockBlockchainPort extends Mock implements PayjoinBlockchainPort {}

class _MockTransactionPort extends Mock implements PayjoinTransactionPort {}

class _MockLabelsPort extends Mock implements PayjoinLabelsPort {}

/// Records nothing as aborted: the write that follows a successful fallback
/// broadcast is what fails.
class _FailingAbortLocal extends LocalPayjoinDatasource {
  _FailingAbortLocal({required super.db});

  @override
  Future<bool> markAborted(PayjoinModel payjoin) =>
      Future.error(StateError('disk full'));
}

final class _CaptureLogPort implements PayjoinLogPort {
  final events = <PayjoinLogEvent>[];

  @override
  void write(PayjoinLogEvent event) => events.add(event);

  Iterable<PayjoinLogEvent> withCode(PayjoinLogCode code) =>
      events.where((event) => event.code == code);
}

void main() {
  late PayjoinDatabase database;
  late LocalPayjoinDatasource local;
  late PayjoinPolicyStore policy;
  late _MockPdkPayjoinDatasource pdk;
  late _MockBlockchainPort blockchain;
  late _MockTransactionPort transactions;
  late _MockLabelsPort labels;
  late _MockWalletPort wallet;
  late StreamController<PayjoinReceiverModel> requests;
  late PayjoinRepositoryImpl engine;
  late _CaptureLogPort logs;

  setUpAll(() {
    registerFallbackValue(BigInt.zero);
    registerFallbackValue(BitcoinNetwork.testnet);
    registerFallbackValue(Uint8List(0));
  });

  PayjoinReceiverModel receiver({
    String id = 'receiver-1',
    Uint8List? originalTransaction,
    String? originalTransactionId,
    String? proposalPsbt,
    String? transactionId,
    bool isTrade = false,
  }) =>
      PayjoinModel.receiver(
            id: id,
            address: 'tb1qreceiver',
            isTestnet: true,
            receiver: '[]',
            walletId: 'wallet-1',
            pjUri: 'bitcoin:tb1qreceiver?pj=https://payjo.in/$id',
            maxFeeRateSatPerVb: BigInt.from(10000),
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            expireAfterSec: 3600,
            originalTxBytes: originalTransaction,
            originalTxId: originalTransactionId,
            amountSat: 50000,
            proposalPsbt: proposalPsbt,
            txId: transactionId,
            isTrade: isTrade,
          )
          as PayjoinReceiverModel;

  PayjoinSenderModel sender() =>
      PayjoinModel.sender(
            uri: 'bitcoin:tb1qsender?pj=https://payjo.in',
            isTestnet: true,
            sender: '[]',
            walletId: 'wallet-1',
            originalPsbt: 'cHNidP8=',
            originalTxId: 'original-tx',
            amountSat: 50000,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            expireAfterSec: 3600,
          )
          as PayjoinSenderModel;

  // Single-input, single-output unsigned PSBT. Real enough for BitcoinTx to
  // extract the spent outpoint, which is what the freeze reads.
  const oneInputPsbt =
      'cHNidP8BAFICAAAAARERERERERERERERERERERERERERERERERERERERERERAAAAAAD9////'
      'AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
      'MzMzMzMzMzMzMzMzMzMzMzMAAA==';

  /// A sender whose expiry elapsed two hours ago, so a resume routes it
  /// straight through the expiry handler (`_resumeOne`).
  PayjoinSenderModel expiredSender({
    String uri = 'bitcoin:tb1qsender?pj=https://payjo.in',
    String? proposalPsbt,
    String? transactionId,
  }) =>
      PayjoinModel.sender(
            uri: uri,
            isTestnet: true,
            sender: '[]',
            walletId: 'wallet-1',
            originalPsbt: oneInputPsbt,
            originalTxId: 'original-tx',
            amountSat: 50000,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 7200,
            expireAfterSec: 3600,
            proposalPsbt: proposalPsbt,
            txId: transactionId,
          )
          as PayjoinSenderModel;

  setUp(() async {
    database = PayjoinDatabase.forTesting(NativeDatabase.memory());
    local = LocalPayjoinDatasource(db: database);
    policy = PayjoinPolicyStore(database);
    await database
        .into(database.payjoinPolicies)
        .insert(
          const PayjoinPolicyRow(
            id: 1,
            receiveEnabled: true,
            sendEnabled: true,
            buyEnabled: true,
            sellEnabled: true,
            minimumAmountSat: 10000,
            sessionLifetimeSeconds: 86400,
          ),
        );
    pdk = _MockPdkPayjoinDatasource();
    blockchain = _MockBlockchainPort();
    transactions = _MockTransactionPort();
    labels = _MockLabelsPort();
    wallet = _MockWalletPort();
    requests = StreamController<PayjoinReceiverModel>.broadcast();
    when(() => pdk.requestsForReceivers).thenAnswer((_) => requests.stream);
    when(() => pdk.proposalsForSenders).thenAnswer((_) => const Stream.empty());
    when(() => pdk.expiredPayjoins).thenAnswer((_) => const Stream.empty());
    when(() => pdk.dispose()).thenAnswer((_) async {});
    when(() => pdk.stopPolling(any())).thenReturn(null);
    when(
      () => transactions.watchWallet(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => transactions.isTransactionVisible(
        walletId: any(named: 'walletId'),
        transactionId: any(named: 'transactionId'),
        refresh: any(named: 'refresh'),
      ),
    ).thenAnswer((_) async => false);
    when(() => transactions.refreshWallet(any())).thenAnswer((_) async {});
    logs = _CaptureLogPort();
    engine = PayjoinRepositoryImpl(
      localPayjoinDatasource: local,
      pdkPayjoinDatasource: pdk,
      log: PayjoinLogger(logs),
      wallet: wallet,
      blockchain: blockchain,
      transactions: transactions,
      policy: policy,
      labels: labels,
    );
  });

  tearDown(() async {
    await engine.dispose();
    await requests.close();
    await database.close();
  });

  test('receiver creation persists before returning', () async {
    final model = receiver();
    when(
      () => pdk.createReceiver(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        isTestnet: any(named: 'isTestnet'),
        maxFeeRateSatPerVb: any(named: 'maxFeeRateSatPerVb'),
        expireAfterSec: any(named: 'expireAfterSec'),
        amountSat: any(named: 'amountSat'),
        isTrade: any(named: 'isTrade'),
      ),
    ).thenAnswer((_) async => model);

    final created = await engine.createPayjoinReceiver(
      walletId: model.walletId,
      address: model.address,
      isTestnet: true,
      maxFeeRateSatPerVb: model.maxFeeRateSatPerVb,
      expireAfterSec: model.expireAfterSec,
      amountSat: model.amountSat,
    );

    expect(created.id, model.id);
    expect(await local.fetchReceiver(model.id), isNotNull);
  });

  group('session milestones', () {
    test('a started receiver is logged on the receiver side', () async {
      final model = receiver(id: '0123456789abcdef');
      when(
        () => pdk.createReceiver(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
          isTestnet: any(named: 'isTestnet'),
          maxFeeRateSatPerVb: any(named: 'maxFeeRateSatPerVb'),
          expireAfterSec: any(named: 'expireAfterSec'),
          amountSat: any(named: 'amountSat'),
          isTrade: any(named: 'isTrade'),
        ),
      ).thenAnswer((_) async => model);

      await engine.createPayjoinReceiver(
        walletId: model.walletId,
        address: model.address,
        isTestnet: true,
        maxFeeRateSatPerVb: model.maxFeeRateSatPerVb,
        expireAfterSec: model.expireAfterSec,
        amountSat: model.amountSat,
      );

      final started = logs.withCode(PayjoinLogCode.sessionStarted).single;
      expect(started.level, PayjoinLogLevel.fine);
      expect(started.role, PayjoinLogRole.receiver);
      expect(started.sessionRef, '0123456789abcdef');
    });

    test('a fallback broadcast is told apart from a payjoin', () async {
      final model = receiver(
        originalTransaction: Uint8List.fromList([1, 2, 3]),
        originalTransactionId: 'original-tx',
      );
      await local.storeReceiver(model);
      when(
        () => blockchain.broadcastTransaction(
          network: BitcoinNetwork.testnet,
          transaction: any(named: 'transaction'),
        ),
      ).thenAnswer((_) async {});

      await engine.tryBroadcastOriginalTransaction(model.toEntity());

      final fallback = logs.withCode(PayjoinLogCode.fallbackBroadcast).single;
      expect(fallback.level, PayjoinLogLevel.fine);
      expect(fallback.role, PayjoinLogRole.receiver);
      expect(logs.withCode(PayjoinLogCode.sessionCompleted), isEmpty);
    });

    test('a cancelled receiver is logged', () async {
      await local.storeReceiver(receiver());

      await engine.cancelReceiver('receiver-1');

      expect(
        logs.withCode(PayjoinLogCode.sessionCancelled).single.role,
        PayjoinLogRole.receiver,
      );
    });

    test('a sender that expired while closed is logged on resume', () async {
      final model = expiredSender();
      await local.storeSender(model);
      when(
        () => blockchain.broadcastPsbt(
          network: any(named: 'network'),
          psbt: any(named: 'psbt'),
        ),
      ).thenThrow(StateError('electrum unavailable'));

      await engine.resumePayjoinsOnStartup();

      final resumed = logs.withCode(PayjoinLogCode.sessionResumed).single;
      expect(resumed.role, PayjoinLogRole.sender);
      // A sender id is the payment request itself; only its digest leaves.
      expect(resumed.sessionRef, matches(RegExp(r'^[0-9a-f]{16}$')));
    });

    // Expiry events are matched by name so these tests compile, and fail for
    // the right reason, against the engine that predates the new codes.
    Iterable<PayjoinLogEvent> named(String name) =>
        logs.events.where((event) => event.code.name == name);

    test('a sender with no proposal recorded says only that', () async {
      await local.storeSender(expiredSender());
      when(
        () => blockchain.broadcastPsbt(
          network: any(named: 'network'),
          psbt: any(named: 'psbt'),
        ),
      ).thenAnswer((_) async {});

      await engine.resumePayjoinsOnStartup();

      final expired = named('expiredWithoutProposal').single;
      expect(expired.role, PayjoinLogRole.sender);
      // Polling may have failed on every relay: local absence is all the
      // engine knows, so nothing may blame the counterparty.
      expect(expired.code.description, isNot(contains('answer')));
    });

    test(
      'a receiver that already proposed is not said to be unanswered',
      () async {
        final model =
            receiver(
              originalTransaction: Uint8List.fromList([1, 2, 3]),
              originalTransactionId: 'original-tx',
              proposalPsbt: 'cHNidP8=',
              transactionId: 'payjoin-tx',
            ).copyWith(
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 7200,
            );
        await local.storeReceiver(model);

        await engine.resumePayjoinsOnStartup();

        final expired = named('expiredMidNegotiation').single;
        expect(expired.role, PayjoinLogRole.receiver);
        expect(expired.code.description, isNot(contains('answer')));
      },
    );

    test(
      'a failed fallback broadcast is told apart from a recorded one',
      () async {
        await local.storeSender(expiredSender());
        when(
          () => blockchain.broadcastPsbt(
            network: any(named: 'network'),
            psbt: any(named: 'psbt'),
          ),
        ).thenThrow(StateError('electrum unavailable'));

        await engine.resumePayjoinsOnStartup();

        expect(named('fallbackBroadcastFailed'), isNotEmpty);
        expect(logs.withCode(PayjoinLogCode.fallbackBroadcast), isEmpty);
      },
    );
  });

  test('a fallback broadcast that could not be recorded is not called a '
      'broadcast failure', () async {
    final failing = _FailingAbortLocal(db: database);
    final failingEngine = PayjoinRepositoryImpl(
      localPayjoinDatasource: failing,
      pdkPayjoinDatasource: pdk,
      log: PayjoinLogger(logs),
      wallet: wallet,
      blockchain: blockchain,
      transactions: transactions,
      policy: policy,
      labels: labels,
    );
    addTearDown(failingEngine.dispose);
    await failing.storeSender(expiredSender());
    when(
      () => blockchain.broadcastPsbt(
        network: any(named: 'network'),
        psbt: any(named: 'psbt'),
      ),
    ).thenAnswer((_) async {});

    await failingEngine.resumePayjoinsOnStartup();

    // The original did reach the network: claiming it failed would send a
    // user to re-pay an order that is already paid.
    expect(logs.withCode(PayjoinLogCode.fallbackBroadcast), isNotEmpty);
    expect(logs.withCode(PayjoinLogCode.broadcastFailure), isEmpty);
    expect(
      logs.events.where(
        (event) => event.code.name == 'fallbackBroadcastFailed',
      ),
      isEmpty,
    );
    expect(logs.withCode(PayjoinLogCode.storageFailure), isNotEmpty);
  });

  test('receiver creation fails closed when policy is disabled', () async {
    await policy.save(PayjoinPolicy.defaults());

    expect(
      () => engine.createPayjoinReceiver(
        walletId: 'wallet-1',
        address: 'tb1qreceiver',
        isTestnet: true,
        maxFeeRateSatPerVb: BigInt.from(10000),
        expireAfterSec: 3600,
      ),
      throwsStateError,
    );
    verifyNever(
      () => pdk.createReceiver(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        isTestnet: any(named: 'isTestnet'),
        maxFeeRateSatPerVb: any(named: 'maxFeeRateSatPerVb'),
        expireAfterSec: any(named: 'expireAfterSec'),
        amountSat: any(named: 'amountSat'),
        isTrade: any(named: 'isTrade'),
      ),
    );
  });

  group('independent receive and buy switches', () {
    test('a buy receiver starts with receiving off and buying on', () async {
      // defaults(): receiving off, buying on — the shipped state.
      await policy.save(PayjoinPolicy.defaults());
      final model = receiver(isTrade: true);
      when(
        () => pdk.createReceiver(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
          isTestnet: any(named: 'isTestnet'),
          maxFeeRateSatPerVb: any(named: 'maxFeeRateSatPerVb'),
          expireAfterSec: any(named: 'expireAfterSec'),
          amountSat: any(named: 'amountSat'),
          isTrade: any(named: 'isTrade'),
        ),
      ).thenAnswer((_) async => model);

      final created = await engine.createPayjoinReceiver(
        walletId: model.walletId,
        address: model.address,
        isTestnet: true,
        maxFeeRateSatPerVb: model.maxFeeRateSatPerVb,
        expireAfterSec: model.expireAfterSec,
        amountSat: model.amountSat,
        isTrade: true,
      );

      expect(created.id, model.id);
      expect(await local.fetchReceiver(model.id), isNotNull);
    });

    test('a buy receiver fails closed when buying is off, even with '
        'receiving on', () async {
      await policy.save(
        PayjoinPolicy.defaults().copyWith(
          receiveEnabled: true,
          buyEnabled: false,
        ),
      );

      expect(
        () => engine.createPayjoinReceiver(
          walletId: 'wallet-1',
          address: 'tb1qreceiver',
          isTestnet: true,
          maxFeeRateSatPerVb: BigInt.from(10000),
          expireAfterSec: 3600,
          isTrade: true,
        ),
        throwsStateError,
      );
    });

    test(
      'turning receiving off settles user receivers but keeps buy ones',
      () async {
        final regular = receiver(id: 'regular');
        final trade = receiver(id: 'trade', isTrade: true);
        await local.storeReceiver(regular);
        await local.storeReceiver(trade);

        final disabled = await policy.setActionEnabled(
          PayjoinAction.receive,
          enabled: false,
        );
        await engine.settleReceiversNotPermittedBy(disabled);

        expect(await local.fetchReceiver(regular.id), isNull);
        expect(await local.fetchReceiver(trade.id), isNotNull);
      },
    );

    test(
      'turning buying off settles buy receivers but keeps user ones',
      () async {
        final regular = receiver(id: 'regular');
        final trade = receiver(id: 'trade', isTrade: true);
        await local.storeReceiver(regular);
        await local.storeReceiver(trade);

        final disabled = await policy.setActionEnabled(
          PayjoinAction.buy,
          enabled: false,
        );
        await engine.settleReceiversNotPermittedBy(disabled);

        expect(await local.fetchReceiver(regular.id), isNotNull);
        expect(await local.fetchReceiver(trade.id), isNull);
      },
    );

    test('settleAllReceivers ignores policy and settles everything', () async {
      final regular = receiver(id: 'regular');
      final trade = receiver(id: 'trade', isTrade: true);
      await local.storeReceiver(regular);
      await local.storeReceiver(trade);

      await engine.settleAllReceivers();

      expect(await local.fetchReceiver(regular.id), isNull);
      expect(await local.fetchReceiver(trade.id), isNull);
    });

    test('startup resumes a buy receiver while receiving is off', () async {
      final trade = receiver(id: 'trade', isTrade: true);
      await local.storeReceiver(trade);
      await policy.save(PayjoinPolicy.defaults());
      when(() => pdk.startListeningForRequest(trade)).thenReturn(null);

      await engine.resumePayjoinsOnStartup();

      expect(await local.fetchReceiver(trade.id), isNotNull);
      verify(() => pdk.startListeningForRequest(trade)).called(1);
    });

    test('startup removes an idle buy receiver while buying is off', () async {
      final trade = receiver(id: 'trade', isTrade: true);
      await local.storeReceiver(trade);
      await policy.setActionEnabled(PayjoinAction.buy, enabled: false);

      await engine.resumePayjoinsOnStartup();

      expect(await local.fetchReceiver(trade.id), isNull);
      verifyNever(() => pdk.startListeningForRequest(trade));
    });

    group('a sender request arriving after a switch changed', () {
      late StreamController<PayjoinReceiverModel> requests;

      setUp(() async {
        // The main setUp's engine listens to an empty request stream; replace
        // it with one this group can feed.
        await engine.dispose();
        registerFallbackValue(receiver());
        requests = StreamController<PayjoinReceiverModel>();
        when(() => pdk.requestsForReceivers).thenAnswer((_) => requests.stream);
        when(() => pdk.declineReceiverSession(any())).thenReturn('[]');
        when(
          () => blockchain.broadcastTransaction(
            network: any(named: 'network'),
            transaction: any(named: 'transaction'),
          ),
        ).thenAnswer((_) async {});
        final wallet = _MockWalletPort();
        when(
          () => wallet.spendableUtxos(
            walletId: any(named: 'walletId'),
            network: any(named: 'network'),
          ),
        ).thenAnswer((_) async => []);
        engine = PayjoinRepositoryImpl(
          localPayjoinDatasource: local,
          pdkPayjoinDatasource: pdk,
          log: PayjoinLogger.silent,
          wallet: wallet,
          blockchain: blockchain,
          transactions: transactions,
          policy: policy,
          labels: labels,
        );
      });

      tearDown(() => requests.close());

      Future<void> deliverRequest(PayjoinReceiverModel stored) async {
        await local.storeReceiver(stored);
        requests.add(
          stored.copyWith(
            originalTxBytes: Uint8List.fromList([1, 2, 3]),
            originalTxId: 'original-tx',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      test('a buy receiver declines and broadcasts the original once buying '
          'is off', () async {
        await policy.setActionEnabled(PayjoinAction.buy, enabled: false);

        await deliverRequest(receiver(id: 'trade', isTrade: true));

        verify(() => pdk.declineReceiverSession(any())).called(1);
        verify(
          () => blockchain.broadcastTransaction(
            network: any(named: 'network'),
            transaction: any(named: 'transaction'),
          ),
        ).called(1);
        expect((await local.fetchReceiver('trade'))?.isAborted, isTrue);
      });

      test('a user receiver is not declined when only buying is off', () async {
        await policy.setActionEnabled(PayjoinAction.buy, enabled: false);

        await deliverRequest(receiver(id: 'regular'));

        verifyNever(() => pdk.declineReceiverSession(any()));
      });
    });
  });

  test('cancel removes an idle receiver without broadcasting', () async {
    final model = receiver();
    await local.storeReceiver(model);

    await engine.cancelReceiver(model.id);

    expect(await local.fetchReceiver(model.id), isNull);
    verifyNever(
      () => blockchain.broadcastTransaction(
        network: any(named: 'network'),
        transaction: any(named: 'transaction'),
      ),
    );
    verify(() => pdk.stopPolling(model.id)).called(1);
  });

  test('cancelling a committed proposal does not claim no payment', () async {
    final model = receiver(proposalPsbt: 'cHNidP9wcm9wb3NhbA==');
    await local.storeReceiver(model);

    await engine.cancelReceiver(model.id);

    expect(await local.fetchReceiver(model.id), isNotNull);
    expect(logs.withCode(PayjoinLogCode.sessionCancelled), isEmpty);
    expect(logs.withCode(PayjoinLogCode.fallbackBroadcast), isEmpty);
  });

  test(
    'cancelling with an original logs its payment, not an idle cancellation',
    () async {
      final model = receiver(
        originalTransaction: Uint8List.fromList([1, 2, 3]),
        originalTransactionId: 'original-tx',
      );
      await local.storeReceiver(model);
      when(() => pdk.declineReceiverSession(model)).thenReturn(model.receiver);
      when(
        () => blockchain.broadcastTransaction(
          network: BitcoinNetwork.testnet,
          transaction: any(named: 'transaction'),
        ),
      ).thenAnswer((_) async {});

      await engine.cancelReceiver(model.id);

      expect(logs.withCode(PayjoinLogCode.sessionCancelled), isEmpty);
      expect(logs.withCode(PayjoinLogCode.fallbackBroadcast), hasLength(1));
      expect((await local.fetchReceiver(model.id))?.isAborted, isTrue);
    },
  );

  test('duplicate sender is rejected before directory publication', () async {
    final model = sender();
    await local.storeSender(model);

    expect(
      () => engine.createPayjoinSender(
        walletId: model.walletId,
        isTestnet: model.isTestnet,
        bip21: model.id,
        originalPsbt: model.originalPsbt,
        amountSat: model.amountSat,
        networkFeesSatPerVb: 1,
      ),
      throwsStateError,
    );
    verifyNever(
      () => pdk.createSender(
        walletId: model.walletId,
        isTestnet: model.isTestnet,
        bip21: model.id,
        originalPsbt: model.originalPsbt,
        networkFeesSatPerVb: 1,
        amountSat: model.amountSat,
        expireAfterSec: null,
        persistBeforePost: any(named: 'persistBeforePost'),
      ),
    );
  });

  test('disabling removes idle receivers but preserves proposals', () async {
    final idle = receiver(id: 'idle');
    final proposed = receiver(
      id: 'proposed',
      proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
    );
    await local.storeReceiver(idle);
    await local.storeReceiver(proposed);

    final disabled = await policy.setActionEnabled(
      PayjoinAction.receive,
      enabled: false,
    );
    await engine.settleReceiversNotPermittedBy(disabled);

    expect(await local.fetchReceiver(idle.id), isNull);
    expect(await local.fetchReceiver(proposed.id), isNotNull);
    verify(() => pdk.stopPolling(idle.id)).called(1);
  });

  test('startup resumes sender proposal polling', () async {
    final model = sender();
    await local.storeSender(model);

    await engine.resumePayjoinsOnStartup();

    verify(() => pdk.startListeningForProposal(model)).called(1);
  });

  test('startup removes idle receivers while policy is disabled', () async {
    final model = receiver();
    await local.storeReceiver(model);
    await policy.save(PayjoinPolicy.defaults());

    await engine.resumePayjoinsOnStartup();

    expect(await local.fetchReceiver(model.id), isNull);
    verifyNever(() => pdk.startListeningForRequest(model));
  });

  test(
    'publishing a proposal gates manual fallback across fresh reads',
    () async {
      final model = receiver(
        originalTransaction: Uint8List.fromList([1, 2, 3]),
        originalTransactionId: 'original-tx',
      );
      final proposal = model.copyWith(
        proposalPsbt: 'proposal',
        txId: 'payjoin-tx',
      );
      await local.storeReceiver(model);
      registerFallbackValue(model);
      registerFallbackValue(<PayjoinInputPairModel>[]);
      registerFallbackValue((Outpoint _) => true);
      registerFallbackValue((Uint8List _) => true);
      registerFallbackValue((String psbt) => psbt);
      when(
        () => wallet.spendableUtxos(
          walletId: model.walletId,
          network: BitcoinNetwork.testnet,
        ),
      ).thenAnswer(
        (_) async => [
          PayjoinUtxo(
            outpoint: (txId: 'wallet-utxo', vout: 0),
            value: Sats.fromInt(100000),
            scriptPubkey: Uint8List.fromList([0, 20]),
            confirmed: true,
          ),
        ],
      );
      when(
        () => wallet.createOwnershipChecker(
          walletId: model.walletId,
          network: BitcoinNetwork.testnet,
        ),
      ).thenAnswer(
        (_) async =>
            (Uint8List _) => true,
      );
      when(
        () => wallet.createOutpointOwnershipChecker(
          walletId: model.walletId,
          network: BitcoinNetwork.testnet,
        ),
      ).thenAnswer(
        (_) async =>
            (Outpoint _) => true,
      );
      when(
        () => pdk.proposePayjoin(
          receiverModel: any(named: 'receiverModel'),
          ownsOutpoint: any(named: 'ownsOutpoint'),
          hasReceiverOutput: any(named: 'hasReceiverOutput'),
          inputPairs: any(named: 'inputPairs'),
          signPsbt: any(named: 'signPsbt'),
        ),
      ).thenAnswer((_) async => proposal);
      final proposed = engine.payjoinStream.firstWhere(
        (session) => session.status == internal.PayjoinStatus.proposed,
      );
      requests.add(model);
      await proposed.timeout(const Duration(seconds: 5));
      final until = engine.receiverFallbackAvailableAt(model.id);
      if (until == null) fail('no sender wait recorded for the session');
      expect(
        until.difference(DateTime.now()).inSeconds,
        inInclusiveRange(58, 60),
      );
      expect(await engine.canManuallyBroadcastOriginal(model.id), isFalse);
      final fresh = await engine.getPayjoinById(model.id);
      if (fresh == null) fail('the proposed session is not persisted');
      final result = await engine.tryBroadcastOriginalTransaction(fresh);
      expect(
        (result as Err<internal.Payjoin, PayjoinFailure>).failure,
        isA<PayjoinFallbackUnavailableFailure>(),
      );
      expect(engine.receiverFallbackAvailableAt(model.id), until);
      verifyNever(
        () => blockchain.broadcastTransaction(
          network: any(named: 'network'),
          transaction: any(named: 'transaction'),
        ),
      );
    },
  );

  test('manual fallback can replace a proposal that is not visible', () async {
    final model = receiver(
      originalTransaction: Uint8List.fromList([1, 2, 3]),
      originalTransactionId: 'original-tx',
      proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
      transactionId: 'payjoin-tx',
    );
    await local.storeReceiver(model);
    when(
      () => blockchain.broadcastTransaction(
        network: BitcoinNetwork.testnet,
        transaction: any(named: 'transaction'),
      ),
    ).thenAnswer((_) async {});
    final result = await engine.tryBroadcastOriginalTransaction(
      model.toEntity(),
    );

    expect(result, isA<Ok<internal.Payjoin, PayjoinFailure>>());
    expect(
      (result as Ok<internal.Payjoin, PayjoinFailure>).value.status,
      internal.PayjoinStatus.aborted,
    );
    verify(
      () => blockchain.broadcastTransaction(
        network: BitcoinNetwork.testnet,
        transaction: any(named: 'transaction'),
      ),
    ).called(1);
  });

  test('manual fallback records the plain transaction as aborted', () async {
    final model = receiver(
      originalTransaction: Uint8List.fromList([1, 2, 3]),
      originalTransactionId: 'original-tx',
    );
    await local.storeReceiver(model);
    when(
      () => blockchain.broadcastTransaction(
        network: BitcoinNetwork.testnet,
        transaction: any(named: 'transaction'),
      ),
    ).thenAnswer((_) async {});

    final result = await engine.tryBroadcastOriginalTransaction(
      model.toEntity(),
    );

    expect(result, isA<Ok<internal.Payjoin, PayjoinFailure>>());
    expect(
      (result as Ok<internal.Payjoin, PayjoinFailure>).value.status,
      internal.PayjoinStatus.aborted,
    );
    final persisted = await local.fetchReceiver(model.id);
    expect(persisted?.isAborted, isTrue);
    expect(persisted?.txId, isNull);
    verifyNever(
      () => labels.labelTransaction(
        walletId: any(named: 'walletId'),
        transactionId: any(named: 'transactionId'),
      ),
    );
  });

  test('manual fallback distinguishes a genuine broadcast failure', () async {
    final model = receiver(
      originalTransaction: Uint8List.fromList([1, 2, 3]),
      originalTransactionId: 'original-tx',
    );
    await local.storeReceiver(model);
    when(
      () => blockchain.broadcastTransaction(
        network: BitcoinNetwork.testnet,
        transaction: any(named: 'transaction'),
      ),
    ).thenThrow(Exception('network unavailable'));

    final result = await engine.tryBroadcastOriginalTransaction(
      model.toEntity(),
    );

    expect(result, isA<Err<internal.Payjoin, PayjoinFailure>>());
    expect(
      (result as Err<internal.Payjoin, PayjoinFailure>).failure,
      isA<PayjoinBroadcastFailure>(),
    );
    final persisted = await local.fetchReceiver(model.id);
    expect(persisted?.isAborted, isFalse);
  });

  test(
    'a failed visibility check never attempts a fallback broadcast',
    () async {
      const originalTxId = 'original-tx';
      final model = receiver(
        originalTransaction: Uint8List.fromList([1, 2, 3]),
        originalTransactionId: originalTxId,
      );
      await local.storeReceiver(model);
      when(
        () => transactions.isTransactionVisible(
          walletId: model.walletId,
          transactionId: originalTxId,
          refresh: true,
        ),
      ).thenThrow(Exception('server unreachable'));
      final result = await engine.tryBroadcastOriginalTransaction(
        model.toEntity(),
      );
      expect(
        (result as Err<internal.Payjoin, PayjoinFailure>).failure,
        isA<PayjoinUnavailableFailure>(),
      );
      expect((await local.fetchReceiver(model.id))?.isAborted, isFalse);
      verifyNever(
        () => blockchain.broadcastTransaction(
          network: any(named: 'network'),
          transaction: any(named: 'transaction'),
        ),
      );
    },
  );

  test('manual fallback settles when the original is visible', () async {
    final model = receiver(
      originalTransaction: Uint8List.fromList([1, 2, 3]),
      originalTransactionId: 'original-tx',
    );
    await local.storeReceiver(model);
    when(
      () => transactions.isTransactionVisible(
        walletId: model.walletId,
        transactionId: model.originalTxId!,
        refresh: true,
      ),
    ).thenAnswer((_) async => true);

    expect(await engine.canManuallyBroadcastOriginal(model.id), isFalse);
    final result = await engine.tryBroadcastOriginalTransaction(
      model.toEntity(),
    );

    expect(
      (result as Ok<internal.Payjoin, PayjoinFailure>).value.isAborted,
      isTrue,
    );
    final persisted = await local.fetchReceiver(model.id);
    expect(persisted?.isAborted, isTrue);
    expect(persisted?.txId, isNull);
    verifyNever(
      () => labels.labelTransaction(
        walletId: any(named: 'walletId'),
        transactionId: any(named: 'transactionId'),
      ),
    );
    verifyNever(
      () => blockchain.broadcastTransaction(
        network: any(named: 'network'),
        transaction: any(named: 'transaction'),
      ),
    );
  });

  test('manual fallback is unavailable when the payjoin is visible', () async {
    final model = expiredSender(
      proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
      transactionId: 'payjoin-tx',
    );
    await local.storeSender(model.copyWith(isExpired: true));
    when(
      () => transactions.isTransactionVisible(
        walletId: model.walletId,
        transactionId: model.txId!,
        refresh: true,
      ),
    ).thenAnswer((_) async => true);

    expect(await engine.canManuallyBroadcastOriginal(model.id), isFalse);
  });

  test('a manual fallback completes a payjoin already visible', () async {
    final model = receiver(
      originalTransaction: Uint8List.fromList([1, 2, 3]),
      originalTransactionId: 'original-tx',
      proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
      transactionId: 'payjoin-tx',
    );
    await local.storeReceiver(model);
    when(
      () => transactions.isTransactionVisible(
        walletId: model.walletId,
        transactionId: 'payjoin-tx',
        refresh: true,
      ),
    ).thenAnswer((_) async => true);
    when(
      () => labels.labelTransaction(
        walletId: any(named: 'walletId'),
        transactionId: any(named: 'transactionId'),
      ),
    ).thenAnswer((_) async {});

    final result = await engine.tryBroadcastOriginalTransaction(
      model.toEntity(),
    );

    // The receiver is already paid: settle instead of reporting the fallback
    // as unavailable and leaving the user waiting on a watcher.
    expect(
      (result as Ok<internal.Payjoin, PayjoinFailure>).value.isCompleted,
      isTrue,
    );
    expect((await local.fetchReceiver(model.id))?.isCompleted, isTrue);
    verifyNever(
      () => blockchain.broadcastTransaction(
        network: any(named: 'network'),
        transaction: any(named: 'transaction'),
      ),
    );
  });

  group('an expired sender is terminal from our side', () {
    test('a failed fallback releases the frozen inputs', () async {
      final model = expiredSender();
      await local.storeSender(model);
      when(
        () => blockchain.broadcastPsbt(
          network: any(named: 'network'),
          psbt: any(named: 'psbt'),
        ),
      ).thenThrow(StateError('electrum unavailable'));

      await engine.resumePayjoinsOnStartup();

      // Holding the inputs hostage while the payment cannot be broadcast locks
      // the user out of their own coins for every send, not just this order.
      expect(await engine.getUtxosFrozenByOngoingPayjoins(), isEmpty);
    });

    test('a failed fallback persists the expiry', () async {
      final model = expiredSender();
      await local.storeSender(model);
      when(
        () => blockchain.broadcastPsbt(
          network: any(named: 'network'),
          psbt: any(named: 'psbt'),
        ),
      ).thenThrow(StateError('electrum unavailable'));

      await engine.resumePayjoinsOnStartup();

      expect((await local.fetchSender(model.id))?.isExpired, isTrue);
    });

    test('a later resume never re-broadcasts the original', () async {
      final model = expiredSender();
      await local.storeSender(model);
      when(
        () => blockchain.broadcastPsbt(
          network: any(named: 'network'),
          psbt: any(named: 'psbt'),
        ),
      ).thenThrow(StateError('electrum unavailable'));

      await engine.resumePayjoinsOnStartup();
      await engine.resumePayjoinsOnStartup();

      // The inputs were released by the first attempt, so the user may have
      // rebuilt the payment on other coins. A second broadcast of this
      // original could then confirm alongside it and pay the order twice.
      verify(
        () => blockchain.broadcastPsbt(
          network: any(named: 'network'),
          psbt: any(named: 'psbt'),
        ),
      ).called(1);
    });

    test('a later resume never broadcasts an abandoned proposal', () async {
      final model = expiredSender(proposalPsbt: 'cHNidP9wcm9wb3NhbA==');
      await local.storeSender(model);

      await engine.resumePayjoinsOnStartup();
      await engine.resumePayjoinsOnStartup();

      verifyNever(
        () => blockchain.broadcastPsbt(
          network: any(named: 'network'),
          psbt: any(named: 'psbt'),
        ),
      );
    });

    test('the receiver keeps retrying its anti-probing fallback', () async {
      // Asymmetry on purpose: the original a receiver holds is the *sender's*
      // payment, and BIP78 makes broadcasting it the receiver's duty. Dropping
      // that retry would strand the counterparty.
      final model = receiver(
        originalTransaction: Uint8List.fromList([1, 2, 3]),
        originalTransactionId: 'original-tx',
      );
      await local.storeReceiver(model);
      when(
        () => blockchain.broadcastTransaction(
          network: any(named: 'network'),
          transaction: any(named: 'transaction'),
        ),
      ).thenThrow(StateError('electrum unavailable'));

      await engine.resumePayjoinsOnStartup();

      expect(
        (await local.fetchReceiver(model.id))?.isExpired,
        isFalse,
        reason: 'the row must stay unfinished so the fallback is retried',
      );
    });

    test('resumes the payjoin-txid watch from the proposal and reconciles when it '
        'lands', () async {
      // Regression: a sender that failed BOTH broadcasts — its payjoin reached
      //  the mempool though the client saw an error, and its original was a
      //  lower-fee conflict —
      //  is persisted expired with txId cleared for display hygiene, while the
      //  payjoin transaction is actually live on-chain. The in-memory
      //  broadcast watcher dies with the app. On the next start the sweep must
      //  re-derive the payjoin txid from the retained proposal PSBT and re-arm
      //  the watcher, so the session reconciles to COMPLETED on the real
      //  payjoin txid instead of being stranded forever showing the
      //  never-broadcast original.
      final payjoinTxId = (await BitcoinTx.fromPsbt(oneInputPsbt)).txid;
      final stranded = expiredSender(proposalPsbt: oneInputPsbt);
      await local.storeSender(stranded.copyWith(isExpired: true, txId: null));

      final walletEvents = StreamController<void>.broadcast();
      addTearDown(walletEvents.close);
      when(
        () => transactions.watchWallet(any()),
      ).thenAnswer((_) => walletEvents.stream);
      when(
        () => transactions.isTransactionVisible(
          walletId: any(named: 'walletId'),
          transactionId: any(named: 'transactionId'),
          refresh: any(named: 'refresh'),
        ),
      ).thenAnswer(
        (inv) async => inv.namedArguments[#transactionId] == payjoinTxId,
      );

      await engine.resumePayjoinsOnStartup();
      walletEvents.add(null);

      final deadline = DateTime.now().add(const Duration(seconds: 5));
      PayjoinSenderModel? row;
      while (DateTime.now().isBefore(deadline)) {
        row = await local.fetchSender(stranded.id);
        if (row?.isCompleted == true) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(
        row?.isCompleted,
        isTrue,
        reason: 'the live payjoin tx must complete the stranded session',
      );
      expect(
        row?.txId,
        payjoinTxId,
        reason: 'reconciliation must record the real payjoin txid',
      );
    });

    test('an unreadable proposal is logged, not silently ignored', () async {
      final stranded = expiredSender(proposalPsbt: 'cHNidP9wcm9wb3NhbA==');
      await local.storeSender(stranded.copyWith(isExpired: true, txId: null));

      await engine.resumePayjoinsOnStartup();

      final warning = logs.withCode(PayjoinLogCode.watchFailure).single;
      expect(warning.level, PayjoinLogLevel.warning);
      expect(warning.sessionRef, stranded.toEntity().logRef);
      expect(
        warning.error,
        isNull,
        reason: 'the parse error may quote the PSBT, which must not be logged',
      );
    });

    test('labels the payjoin when a stranded sender reconciles', () async {
      // The live broadcast path labels the sender's payjoin itself. A sender
      //  reconciled by the watcher never goes through it, so the payment would
      //  otherwise show in history without the payjoin label.
      final payjoinTxId = (await BitcoinTx.fromPsbt(oneInputPsbt)).txid;
      final stranded = expiredSender(proposalPsbt: oneInputPsbt);
      await local.storeSender(stranded.copyWith(isExpired: true, txId: null));

      final labelled = Completer<String>();
      when(
        () => labels.labelTransaction(
          walletId: any(named: 'walletId'),
          transactionId: any(named: 'transactionId'),
        ),
      ).thenAnswer((inv) async {
        labelled.complete(inv.namedArguments[#transactionId] as String);
      });
      final walletEvents = StreamController<void>.broadcast();
      addTearDown(walletEvents.close);
      when(
        () => transactions.watchWallet(any()),
      ).thenAnswer((_) => walletEvents.stream);
      when(
        () => transactions.isTransactionVisible(
          walletId: any(named: 'walletId'),
          transactionId: any(named: 'transactionId'),
          refresh: any(named: 'refresh'),
        ),
      ).thenAnswer(
        (inv) async => inv.namedArguments[#transactionId] == payjoinTxId,
      );

      await engine.resumePayjoinsOnStartup();
      walletEvents.add(null);

      expect(
        await labelled.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => 'never labelled',
        ),
        payjoinTxId,
      );
    });

    test(
      'without a proposal, an expired sender arms no broadcast watcher',
      () async {
        // The counterpart to the regression test: no proposal was ever
        //  exchanged, so no payjoin transaction can exist. The sweep must not
        //  fabricate a broadcast watch (only the fallback observer applies).
        final stranded = sender();
        await local.storeSender(stranded.copyWith(isExpired: true, txId: null));

        final walletEvents = StreamController<void>.broadcast();
        addTearDown(walletEvents.close);
        when(
          () => transactions.watchWallet(any()),
        ).thenAnswer((_) => walletEvents.stream);
        when(
          () => transactions.isTransactionVisible(
            walletId: any(named: 'walletId'),
            transactionId: any(named: 'transactionId'),
            refresh: any(named: 'refresh'),
          ),
        ).thenAnswer((_) async => true);

        await engine.resumePayjoinsOnStartup();
        walletEvents.add(null);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // A sender with no proposal must never be "completed" as a payjoin,
        //  even if some unrelated transaction is visible.
        expect((await local.fetchSender(stranded.id))?.isCompleted, isFalse);
      },
    );
  });

  test(
    'a retry keeps watching the superseded payjoin and completes on it',
    () async {
      // A retry replaces the stranded row under the same id. If the first
      //  attempt's payjoin then lands, the payment is made: the retried session
      //  must complete on it, which also stops its own fallback from
      //  broadcasting a second payment on possibly different inputs.
      final payjoinTxId = (await BitcoinTx.fromPsbt(oneInputPsbt)).txid;
      final stranded = expiredSender(proposalPsbt: oneInputPsbt);
      await local.storeSender(stranded.copyWith(isExpired: true, txId: null));

      final walletEvents = StreamController<void>.broadcast();
      addTearDown(walletEvents.close);
      when(
        () => transactions.watchWallet(any()),
      ).thenAnswer((_) => walletEvents.stream);
      await engine.resumePayjoinsOnStartup();

      final retried = sender().copyWith(originalTxId: 'retried-tx');
      when(
        () => pdk.createSender(
          walletId: any(named: 'walletId'),
          isTestnet: any(named: 'isTestnet'),
          bip21: any(named: 'bip21'),
          originalPsbt: any(named: 'originalPsbt'),
          networkFeesSatPerVb: any(named: 'networkFeesSatPerVb'),
          amountSat: any(named: 'amountSat'),
          expireAfterSec: any(named: 'expireAfterSec'),
          persistBeforePost: any(named: 'persistBeforePost'),
        ),
      ).thenAnswer((inv) async {
        final persist =
            inv.namedArguments[#persistBeforePost]
                as Future<void> Function(PayjoinSenderModel);
        await persist(retried);
        return retried;
      });
      await engine.createPayjoinSender(
        walletId: retried.walletId,
        isTestnet: true,
        bip21: retried.id,
        originalPsbt: retried.originalPsbt,
        amountSat: retried.amountSat,
        networkFeesSatPerVb: 1,
      );

      when(
        () => transactions.isTransactionVisible(
          walletId: any(named: 'walletId'),
          transactionId: any(named: 'transactionId'),
          refresh: any(named: 'refresh'),
        ),
      ).thenAnswer(
        (inv) async => inv.namedArguments[#transactionId] == payjoinTxId,
      );
      walletEvents.add(null);

      final deadline = DateTime.now().add(const Duration(seconds: 5));
      PayjoinSenderModel? row;
      while (DateTime.now().isBefore(deadline)) {
        row = await local.fetchSender(retried.id);
        if (row?.isCompleted == true) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(row?.isCompleted, isTrue);
      expect(row?.txId, payjoinTxId);
    },
  );

  group('a retried sender', () {
    // A second proposal for the same payment, on a payjoin of its own.
    const retriedProposalPsbt =
        'cHNidP8BAFICAAAAARERERERERERERERERERERERERERERERERERERERERERAAAAAAD9////'
        'AZCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
        'MzMzMzMzMzMzMzMzMzMzMzMAAA==';
    late StreamController<void> walletEvents;
    late String supersededTxId;
    late String retriedTxId;

    /// Strands a sender on [oneInputPsbt], resumes it so its payjoin is
    /// watched, then retries the payment under the same id.
    Future<PayjoinSenderModel> strandAndRetry() async {
      supersededTxId = (await BitcoinTx.fromPsbt(oneInputPsbt)).txid;
      retriedTxId = (await BitcoinTx.fromPsbt(retriedProposalPsbt)).txid;
      final stranded = expiredSender(proposalPsbt: oneInputPsbt);
      await local.storeSender(stranded.copyWith(isExpired: true, txId: null));
      walletEvents = StreamController<void>.broadcast();
      addTearDown(walletEvents.close);
      when(
        () => transactions.watchWallet(any()),
      ).thenAnswer((_) => walletEvents.stream);
      await engine.resumePayjoinsOnStartup();

      final retried = sender().copyWith(originalTxId: 'retried-tx');
      when(
        () => pdk.createSender(
          walletId: any(named: 'walletId'),
          isTestnet: any(named: 'isTestnet'),
          bip21: any(named: 'bip21'),
          originalPsbt: any(named: 'originalPsbt'),
          networkFeesSatPerVb: any(named: 'networkFeesSatPerVb'),
          amountSat: any(named: 'amountSat'),
          expireAfterSec: any(named: 'expireAfterSec'),
          persistBeforePost: any(named: 'persistBeforePost'),
        ),
      ).thenAnswer((inv) async {
        final persist =
            inv.namedArguments[#persistBeforePost]
                as Future<void> Function(PayjoinSenderModel);
        await persist(retried);
        return retried;
      });
      await engine.createPayjoinSender(
        walletId: retried.walletId,
        isTestnet: true,
        bip21: retried.id,
        originalPsbt: retried.originalPsbt,
        amountSat: retried.amountSat,
        networkFeesSatPerVb: 1,
      );
      return retried;
    }

    void onlyVisible(String txId) => when(
      () => transactions.isTransactionVisible(
        walletId: any(named: 'walletId'),
        transactionId: any(named: 'transactionId'),
        refresh: any(named: 'refresh'),
      ),
    ).thenAnswer((inv) async => inv.namedArguments[#transactionId] == txId);

    Future<PayjoinSenderModel?> completedRow(String id) async {
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      PayjoinSenderModel? row;
      while (DateTime.now().isBefore(deadline)) {
        row = await local.fetchSender(id);
        if (row?.isCompleted == true) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      return row;
    }

    test('watches its own payjoin alongside the superseded one', () async {
      // The retried payjoin reaches the network but our client sees an error,
      //  and the wallet has not synced it yet, so the session expires. Its own
      //  payjoin watcher must still be armed despite the superseded one.
      final retried = await strandAndRetry();
      await local.recordSenderProposal(
        retried.copyWith(proposalPsbt: retriedProposalPsbt, txId: retriedTxId),
      );
      when(
        () => wallet.signPsbt(
          walletId: any(named: 'walletId'),
          network: any(named: 'network'),
          psbt: any(named: 'psbt'),
        ),
      ).thenAnswer((_) async => 'c2lnbmVk');
      when(
        () => blockchain.broadcastPsbt(
          network: any(named: 'network'),
          psbt: any(named: 'psbt'),
        ),
      ).thenThrow(StateError('connection reset after send'));
      await engine.resumePayjoinsOnStartup();
      expect((await local.fetchSender(retried.id))?.isExpired, isTrue);

      onlyVisible(retriedTxId);
      walletEvents.add(null);

      final row = await completedRow(retried.id);
      expect(row?.isCompleted, isTrue);
      expect(row?.txId, retriedTxId);
    });

    test('records the payjoin actually seen, not its own proposal', () async {
      // The retried session already holds its new proposal's txid when the
      //  superseded payjoin lands: the row must name the transaction that is
      //  on the network.
      final retried = await strandAndRetry();
      await local.recordSenderProposal(
        retried.copyWith(proposalPsbt: retriedProposalPsbt, txId: retriedTxId),
      );

      onlyVisible(supersededTxId);
      walletEvents.add(null);

      final row = await completedRow(retried.id);
      expect(row?.isCompleted, isTrue);
      expect(row?.txId, supersededTxId);
    });
  });

  test('a payjoin broadcast that errors after reaching the network completes '
      'the sender without the original fallback', () async {
    // Only the sender can sign its own inputs, so a payjoin already on the
    //  network while our broadcast reports an error is our own broadcast that
    //  got through (a dropped Tor circuit, an Electrum timeout). The original
    //  can only be a losing conflict then, and the session must not expire.
    final payjoinTxId = (await BitcoinTx.fromPsbt(oneInputPsbt)).txid;
    final live = sender().copyWith(
      proposalPsbt: oneInputPsbt,
      txId: payjoinTxId,
    );
    await local.storeSender(live);

    when(
      () => wallet.signPsbt(
        walletId: any(named: 'walletId'),
        network: any(named: 'network'),
        psbt: any(named: 'psbt'),
      ),
    ).thenAnswer((_) async => 'c2lnbmVk');
    when(
      () => blockchain.broadcastPsbt(
        network: any(named: 'network'),
        psbt: any(named: 'psbt'),
      ),
    ).thenThrow(StateError('connection reset after send'));
    when(
      () => labels.labelTransaction(
        walletId: any(named: 'walletId'),
        transactionId: any(named: 'transactionId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => transactions.isTransactionVisible(
        walletId: any(named: 'walletId'),
        transactionId: any(named: 'transactionId'),
        refresh: any(named: 'refresh'),
      ),
    ).thenAnswer(
      (inv) async => inv.namedArguments[#transactionId] == payjoinTxId,
    );

    await engine.resumePayjoinsOnStartup();

    final row = await local.fetchSender(live.id);
    expect(row?.isCompleted, isTrue);
    expect(row?.isExpired, isFalse);
    expect(row?.txId, payjoinTxId);
    verifyNever(
      () => blockchain.broadcastPsbt(
        network: any(named: 'network'),
        psbt: live.originalPsbt,
      ),
    );
  });

  test(
    'disabling continues with later receivers after one settlement fails',
    () async {
      final failing = receiver(
        id: 'failing',
        originalTransaction: Uint8List.fromList([1, 2, 3]),
        originalTransactionId: 'failing-original',
      );
      final idle = receiver(id: 'idle-after-failure');
      await local.storeReceiver(failing);
      await local.storeReceiver(idle);
      engine.fallbackRetryDelay = Duration.zero;
      when(() => pdk.declineReceiverSession(failing)).thenReturn('[]');
      when(
        () => blockchain.broadcastTransaction(
          network: BitcoinNetwork.testnet,
          transaction: any(named: 'transaction'),
        ),
      ).thenThrow(StateError('electrum unavailable'));

      final disabled = await policy.setActionEnabled(
        PayjoinAction.receive,
        enabled: false,
      );
      await expectLater(
        engine.settleReceiversNotPermittedBy(disabled),
        throwsStateError,
      );

      expect(
        await local.fetchReceiver(idle.id),
        isNull,
        reason: 'one failed receiver must not abort the rest of the sweep',
      );
      verify(
        () => blockchain.broadcastTransaction(
          network: BitcoinNetwork.testnet,
          transaction: any(named: 'transaction'),
        ),
      ).called(3);
    },
  );

  group('audit reproducers (H1, H2)', () {
    test(
      'manual fallback broadcasts the persisted entity, not the caller copy',
      () async {
        // The persisted row is the fresh session — e.g. after an
        // expired-sender retry swapped in a new original PSBT.
        final fresh = sender();
        await local.storeSender(fresh);
        when(
          () => blockchain.broadcastPsbt(
            network: any(named: 'network'),
            psbt: any(named: 'psbt'),
          ),
        ).thenAnswer((_) async {});

        // The caller holds a STALE snapshot of the same session: same id,
        // but the superseded original PSBT.
        final stale = (fresh.toEntity() as internal.PayjoinSender).copyWith(
          originalPsbt: 'b2xkc3RhbGU=',
        );

        await engine.tryBroadcastOriginalTransaction(stale);

        final captured = verify(
          () => blockchain.broadcastPsbt(
            network: any(named: 'network'),
            psbt: captureAny(named: 'psbt'),
          ),
        ).captured;
        expect(
          captured.single,
          fresh.originalPsbt,
          reason:
              'broadcasting the caller\'s stale entity sends the SUPERSEDED '
              'original while the fresh session gets marked aborted against '
              'it — old and new need not conflict, so both can confirm',
        );
      },
    );

    test('a retried sender watches its own new original transaction', () async {
      // First attempt: a live sender, whose fallback watcher arms on its
      // original txid at creation.
      final first = sender();
      when(
        () => pdk.createSender(
          walletId: any(named: 'walletId'),
          isTestnet: any(named: 'isTestnet'),
          bip21: any(named: 'bip21'),
          originalPsbt: any(named: 'originalPsbt'),
          networkFeesSatPerVb: any(named: 'networkFeesSatPerVb'),
          amountSat: any(named: 'amountSat'),
          expireAfterSec: any(named: 'expireAfterSec'),
          persistBeforePost: any(named: 'persistBeforePost'),
        ),
      ).thenAnswer((inv) async {
        // Mirror the real datasource: the write-ahead persist runs before
        // the (mocked) directory publication.
        final persist =
            inv.namedArguments[#persistBeforePost]
                as Future<void> Function(PayjoinSenderModel);
        await persist(first);
        return first;
      });
      final walletEvents = StreamController<void>.broadcast();
      addTearDown(walletEvents.close);
      when(
        () => transactions.watchWallet(any()),
      ).thenAnswer((_) => walletEvents.stream);

      await engine.createPayjoinSender(
        walletId: first.walletId,
        isTestnet: true,
        bip21: first.id,
        originalPsbt: first.originalPsbt,
        amountSat: first.amountSat,
        networkFeesSatPerVb: 1,
      );

      // The first attempt expires with its automatic fallback broadcast
      // having failed (e.g. offline): the session becomes retryable and its
      // watcher deliberately stays armed.
      await local.markExpired(first.copyWith(isExpired: true));

      // Retry: a NEW original PSBT, hence a NEW original txid.
      final retried = sender().copyWith(originalTxId: 'retried-tx');
      when(
        () => pdk.createSender(
          walletId: any(named: 'walletId'),
          isTestnet: any(named: 'isTestnet'),
          bip21: any(named: 'bip21'),
          originalPsbt: any(named: 'originalPsbt'),
          networkFeesSatPerVb: any(named: 'networkFeesSatPerVb'),
          amountSat: any(named: 'amountSat'),
          expireAfterSec: any(named: 'expireAfterSec'),
          persistBeforePost: any(named: 'persistBeforePost'),
        ),
      ).thenAnswer((inv) async {
        final persist =
            inv.namedArguments[#persistBeforePost]
                as Future<void> Function(PayjoinSenderModel);
        await persist(retried);
        return retried;
      });

      await engine.createPayjoinSender(
        walletId: retried.walletId,
        isTestnet: true,
        bip21: retried.id,
        originalPsbt: retried.originalPsbt,
        amountSat: retried.amountSat,
        networkFeesSatPerVb: 1,
      );

      // The new original lands on-chain (the receiver broadcasts it, as
      // BIP78's fallback allows). The retried session must converge to
      // aborted — it can only do so if its OWN txid is being watched.
      when(
        () => transactions.isTransactionVisible(
          walletId: any(named: 'walletId'),
          transactionId: any(named: 'transactionId'),
          refresh: any(named: 'refresh'),
        ),
      ).thenAnswer(
        (inv) async => inv.namedArguments[#transactionId] == 'retried-tx',
      );
      walletEvents.add(null);

      final deadline = DateTime.now().add(const Duration(seconds: 5));
      PayjoinSenderModel? row;
      while (DateTime.now().isBefore(deadline)) {
        row = await local.fetchSender(first.id);
        if (row?.isAborted == true) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(
        row?.isAborted,
        isTrue,
        reason:
            'a fallback watcher deduped on the session id alone keeps '
            'watching the SUPERSEDED original and never arms the new one',
      );
    });

    test(
      'the persisted sender session state matches the returned model',
      () async {
        // The write-ahead persist stores the PRE-POST session state; the
        // datasource returns the model refreshed to the POST-POST state
        // (PollingForProposal). The engine must bring the row to that same
        // live state, or a resume replays the pre-POST state and the
        // proposal poll never advances (the stall this guards).
        final model = sender();
        when(
          () => pdk.createSender(
            walletId: any(named: 'walletId'),
            isTestnet: any(named: 'isTestnet'),
            bip21: any(named: 'bip21'),
            originalPsbt: any(named: 'originalPsbt'),
            networkFeesSatPerVb: any(named: 'networkFeesSatPerVb'),
            amountSat: any(named: 'amountSat'),
            expireAfterSec: any(named: 'expireAfterSec'),
            persistBeforePost: any(named: 'persistBeforePost'),
          ),
        ).thenAnswer((inv) async {
          final persist =
              inv.namedArguments[#persistBeforePost]
                  as Future<void> Function(PayjoinSenderModel);
          await persist(model);
          return model;
        });

        await engine.createPayjoinSender(
          walletId: model.walletId,
          isTestnet: model.isTestnet,
          bip21: model.id,
          originalPsbt: model.originalPsbt,
          amountSat: model.amountSat,
          networkFeesSatPerVb: 1,
        );

        final persisted = await local.fetchSender(model.id);
        expect(persisted, isNotNull);
        expect(persisted!.sender, model.sender);
      },
    );
  });
}
