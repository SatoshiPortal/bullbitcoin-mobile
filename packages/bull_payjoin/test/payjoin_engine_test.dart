import 'dart:typed_data';

import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_payjoin/src/data/local_payjoin_datasource.dart';
import 'package:bull_payjoin/src/data/payjoin_database.dart';
import 'package:bull_payjoin/src/data/payjoin_model.dart';
import 'package:bull_payjoin/src/data/payjoin_policy_store.dart';
import 'package:bull_payjoin/src/engine/payjoin.dart' as internal;
import 'package:bull_payjoin/src/engine/payjoin_engine.dart';
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

void main() {
  late PayjoinDatabase database;
  late LocalPayjoinDatasource local;
  late PayjoinPolicyStore policy;
  late _MockPdkPayjoinDatasource pdk;
  late _MockBlockchainPort blockchain;
  late _MockTransactionPort transactions;
  late _MockLabelsPort labels;
  late PayjoinRepositoryImpl engine;

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

  setUp(() async {
    database = PayjoinDatabase.forTesting(NativeDatabase.memory());
    local = LocalPayjoinDatasource(db: database);
    policy = PayjoinPolicyStore(database);
    await database
        .into(database.payjoinPolicies)
        .insert(
          const PayjoinPolicyRow(
            id: 1,
            enabled: true,
            minimumAmountSat: 10000,
            sessionLifetimeSeconds: 86400,
          ),
        );
    pdk = _MockPdkPayjoinDatasource();
    blockchain = _MockBlockchainPort();
    transactions = _MockTransactionPort();
    labels = _MockLabelsPort();
    when(
      () => pdk.requestsForReceivers,
    ).thenAnswer((_) => const Stream.empty());
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
    engine = PayjoinRepositoryImpl(
      localPayjoinDatasource: local,
      pdkPayjoinDatasource: pdk,
      wallet: _MockWalletPort(),
      blockchain: blockchain,
      transactions: transactions,
      policy: policy,
      labels: labels,
    );
  });

  tearDown(() async {
    await engine.dispose();
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
      ),
    );
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

    await engine.disableReceivers();

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
    'manual fallback cannot replace an already-published proposal',
    () async {
      final model = receiver(
        originalTransaction: Uint8List.fromList([1, 2, 3]),
        originalTransactionId: 'original-tx',
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
        transactionId: 'payjoin-tx',
      );
      await local.storeReceiver(model);

      final result = await engine.tryBroadcastOriginalTransaction(
        model.toEntity(),
      );

      expect(result?.status, internal.PayjoinStatus.proposed);
      verifyNever(
        () => blockchain.broadcastTransaction(
          network: any(named: 'network'),
          transaction: any(named: 'transaction'),
        ),
      );
    },
  );

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

    expect(result?.status, internal.PayjoinStatus.aborted);
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

      await expectLater(engine.disableReceivers(), throwsStateError);

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
}
