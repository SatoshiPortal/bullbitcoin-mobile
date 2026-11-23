import 'package:send/src/replace_by_fee/domain/bump_fee_usecase.dart';
import 'package:send/src/replace_by_fee/domain/replace_by_fee_failure.dart';
import 'package:fees/fees.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';
import 'package:spend/testing.dart';

class _MockFees extends Mock implements Fees {}

class _Spend extends FakeSpend {
  final List<({String walletId, String txid, BitcoinNetwork network})> calls =
      [];
  Result<void, SpendFailure> verification = const Ok(null);
  Result<SpendBroadcastReceipt, SpendFailure> replacement = const Ok((
    txid: 'replacement',
    durable: false,
    guarded: true,
  ));
  RelativeFee? rate;

  @override
  Future<Result<void, SpendFailure>> verifyOriginalBitcoin({
    required String walletId,
    required String originalTxid,
    required BitcoinNetwork network,
  }) async {
    calls.add((walletId: walletId, txid: originalTxid, network: network));
    return verification;
  }

  @override
  Future<Result<SpendBroadcastReceipt, SpendFailure>> replaceBitcoin({
    required String walletId,
    required String originalTxid,
    required BitcoinNetwork network,
    required RelativeFee newFeeRate,
  }) async {
    calls.add((walletId: walletId, txid: originalTxid, network: network));
    rate = newFeeRate;
    return replacement;
  }
}

void main() {
  late _Spend spend;
  late _MockFees fees;
  late BumpFeeUsecase usecase;

  setUp(() {
    spend = _Spend();
    fees = _MockFees();
    usecase = BumpFeeUsecase(spend: spend, fees: fees);
  });

  const network = BitcoinNetwork.mainnet;
  const target = (
    walletId: 'w1',
    txid: 'original',
    network: BitcoinNetwork.mainnet,
  );
  const newFeeRate = RelativeFee(1250);

  Future<Result<String, ReplaceByFeeFailure>> replace() => usecase.execute(
    walletId: target.walletId,
    txid: target.txid,
    newFeeRate: newFeeRate,
    network: network,
  );

  Future<Result<void, ReplaceByFeeFailure>> verify() =>
      usecase.verifyOriginalTransaction(
        walletId: target.walletId,
        txid: target.txid,
        network: network,
      );

  test(
    'replaces on the reviewed network and accepts a non-durable receipt',
    () async {
      expect(
        await replace(),
        isA<Ok<String, ReplaceByFeeFailure>>().having(
          (result) => result.value,
          'txid',
          'replacement',
        ),
      );
      expect(spend.calls, [target]);
      expect(spend.rate, newFeeRate);
    },
  );

  test('verifies the exact original on the reviewed network', () async {
    expect(await verify(), isA<Ok<void, ReplaceByFeeFailure>>());
    expect(spend.calls, [target]);
  });

  for (final (failure, expected) in <(SpendFailure, Matcher)>[
    (
      const SpendOriginalSignaturesFailure(unverifiable: false),
      isA<ReplaceByFeeManipulatedTransactionFailure>(),
    ),
    (
      const SpendOriginalSignaturesFailure(unverifiable: true),
      isA<ReplaceByFeeUnverifiableTransactionFailure>(),
    ),
    (const SpendUnexpectedFailure(), isA<ReplaceByFeeUnexpectedFailure>()),
  ]) {
    test('maps ${failure.runtimeType} ($expected) in both stages', () async {
      spend.verification = Err(failure);
      spend.replacement = Err(failure);
      expect((await verify() as Err).failure, expected);
      expect((await replace() as Err).failure, expected);
    });
  }

  test('preserves busy and pending replacement refusals', () async {
    spend.replacement = const Err(SpendUnavailableFailure(busy: true));
    expect(
      (await replace() as Err).failure,
      isA<ReplaceByFeeSpendBlockedFailure>().having(
        (f) => f.busy,
        'busy',
        true,
      ),
    );
    spend.replacement = const Err(
      SpendUnavailableFailure(replacementPending: true),
    );
    expect(
      (await replace() as Err).failure,
      isA<ReplaceByFeeSpendBlockedFailure>().having(
        (f) => f.replacementPending,
        'pending',
        true,
      ),
    );
  });

  test('preserves the fee rate refusal', () async {
    spend.replacement = const Err(SpendFeeRateTooLowFailure());
    expect(
      (await replace() as Err).failure,
      isA<ReplaceByFeeFeeRateTooLowFailure>(),
    );
  });

  test('returns the fee presets', () async {
    const options = FeeOptions(
      fastest: NetworkFee.relativeSatPerKwu(10),
      economic: NetworkFee.relativeSatPerKwu(5),
      slow: NetworkFee.relativeSatPerKwu(1),
      minRelay: RelativeFee(25),
    );
    when(() => fees.estimate(BitcoinNetwork.mainnet))
        .thenAnswer((_) async => const Ok(options));
    expect(
      await usecase.getNetworkFees(network),
      isA<Ok<FeeOptions, ReplaceByFeeFailure>>().having(
        (result) => result.value,
        'options',
        options,
      ),
    );
  });

  test('reports unavailability when fees cannot be fetched', () async {
    when(() => fees.estimate(BitcoinNetwork.mainnet))
        .thenAnswer((_) async => const Err(FeeEstimateUnavailableFailure()));
    expect(
      (await usecase.getNetworkFees(network) as Err).failure,
      isA<ReplaceByFeeNetworkFeesFailure>(),
    );
  });
}
