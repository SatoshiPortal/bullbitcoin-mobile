import 'package:bb_mobile/features/broadcast_signed_tx/application/build_reviewable_transaction_usecase.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/reviewable_transaction.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/transaction_review_failure.dart';
import 'package:electrum/electrum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show BitcoinTx, TxScriptSig, TxVin, TxVout;

class _MockElectrum extends Mock implements ElectrumTransactions {}

BitcoinTx _transaction({
  required String txid,
  List<TxVin> inputs = const [],
  List<TxVout> outputs = const [],
}) => BitcoinTx(
  txid: txid,
  version: 2,
  size: BigInt.one,
  vsize: BigInt.one,
  locktime: 0,
  vin: inputs,
  vout: outputs,
);

BitcoinTx _spendingParent(int outputIndex) => _transaction(
  txid: 'spenttxid',
  inputs: [
    TxVin(txid: 'parenttxid', vout: outputIndex, sequence: 0, scriptSig: null),
  ],
);

void main() {
  late _MockElectrum electrum;
  late BuildReviewableTransactionUsecase usecase;

  setUpAll(() => registerFallbackValue(BitcoinNetwork.mainnet));

  setUp(() {
    electrum = _MockElectrum();
    usecase = BuildReviewableTransactionUsecase(electrum: electrum);
  });

  Future<Result<ReviewableTransaction, TransactionReviewFailure>> review(
    BitcoinTx tx, {
    BitcoinNetwork? network = BitcoinNetwork.mainnet,
  }) => usecase.execute(tx, network: Future.value(network));

  test('maps Electrum lookup failures to the review failure family', () async {
    when(() => electrum.fetch('parenttxid', network: BitcoinNetwork.mainnet))
        .thenAnswer(
          (_) async => const Err(ElectrumTransactionFetchFailure('parenttxid')),
        );

    final result = await review(_spendingParent(0));

    expect(
      result,
      isA<Err<ReviewableTransaction, TransactionReviewFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<TransactionReviewFetchFailure>().having(
          (failure) => failure.txid,
          'txid',
          'parenttxid',
        ),
      ),
    );
  });

  test(
    'returns an input-resolution failure when the vout is out of range',
    () async {
      when(() => electrum.fetch('parenttxid', network: BitcoinNetwork.mainnet))
          .thenAnswer((_) async => Ok(_transaction(txid: 'parenttxid')));

      final result = await review(_spendingParent(5));

      expect(
        result,
        isA<Err<ReviewableTransaction, TransactionReviewFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<TransactionReviewInputResolutionFailure>(),
        ),
      );
    },
  );

  test('resolves the input value and address from the parsed parent', () async {
    final parent = _transaction(
      txid: 'parenttxid',
      outputs: [
        TxVout(
          value: BigInt.from(4200),
          n: 0,
          scriptPubKey: TxScriptSig(bytes: [0, 20, ...List.filled(20, 0x22)]),
        ),
      ],
    );
    when(() => electrum.fetch('parenttxid', network: BitcoinNetwork.mainnet))
        .thenAnswer((_) async => Ok(parent));

    final result = await review(_spendingParent(0));

    final reviewable =
        (result as Ok<ReviewableTransaction, TransactionReviewFailure>).value;
    expect(reviewable.resolvedInputs.single.valueSat, 4200);
    expect(reviewable.resolvedInputs.single.address, startsWith('bc1q'));
  });

  test('an unavailable Bitcoin network prevents any parent lookup', () async {
    when(() => electrum.fetch('parenttxid', network: any(named: 'network')))
        .thenAnswer((_) async => Ok(_transaction(txid: 'parenttxid')));

    final result = await review(_spendingParent(0), network: null);

    expect(
      result,
      isA<Err<ReviewableTransaction, TransactionReviewFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<TransactionReviewNoServersFailure>(),
      ),
    );
    verifyZeroInteractions(electrum);
  });

  test('every parent lookup uses the captured review network', () async {
    final parent = _transaction(
      txid: 'parenttxid',
      outputs: [
        TxVout(
          value: BigInt.from(4200),
          n: 0,
          scriptPubKey: TxScriptSig(bytes: [0, 20, ...List.filled(20, 0x22)]),
        ),
      ],
    );
    when(() => electrum.fetch('parenttxid', network: BitcoinNetwork.testnet))
        .thenAnswer((_) async => Ok(parent));

    final result = await review(
      _transaction(
        txid: 'spenttxid',
        inputs: [
          _spendingParent(0).inputs.single,
          _spendingParent(0).inputs.single,
        ],
      ),
      network: BitcoinNetwork.testnet,
    );

    final transaction =
        (result as Ok<ReviewableTransaction, TransactionReviewFailure>).value;
    expect(
      transaction.resolvedInputs.map((input) => input.address),
      everyElement(startsWith('tb1q')),
    );
    verify(() => electrum.fetch('parenttxid', network: BitcoinNetwork.testnet))
        .called(2);
    verifyNoMoreInteractions(electrum);
  });
}
