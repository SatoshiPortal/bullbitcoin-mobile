import 'package:bull_exchange/src/payin/domain/usecases/build_payin_usecase.dart';
import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:fees/fees.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';
import 'package:spend/testing.dart';

import '../../payin_fixtures.dart';

final class _Spend extends FakeSpend {
  final Result<PreparedBitcoinSpend, SpendFailure> bitcoin;
  final Result<SignedBitcoinSpend, SpendFailure> signed;
  final Result<PreparedLiquidSpend, SpendFailure> liquid;
  final asked = <String>[];

  _Spend({
    this.bitcoin = const Err(SpendUnexpectedFailure()),
    this.signed = const Err(SpendUnexpectedFailure()),
    this.liquid = const Err(SpendUnexpectedFailure()),
  });

  @override
  Future<Result<PreparedBitcoinSpend, SpendFailure>> prepareBitcoin({
    required String walletId,
    required List<BitcoinTransactionRecipient> recipients,
    required NetworkFee networkFee,
    Set<Outpoint>? selectedInputs,
    bool selectedOnly = false,
    bool replaceByFee = true,
  }) async {
    final recipient = recipients.single;
    asked.add(
      'prepare bitcoin $walletId ${recipient.address} '
      '${recipient.amountSat?.value} ${(networkFee as RelativeFee).satPerKwu} '
      'rbf=$replaceByFee inputs=$selectedInputs',
    );
    return bitcoin;
  }

  @override
  Future<Result<SignedBitcoinSpend, SpendFailure>> signBitcoin({
    required PreparedBitcoinSpend prepared,
  }) async {
    asked.add('sign bitcoin');
    return signed;
  }

  @override
  Future<Result<PreparedLiquidSpend, SpendFailure>> prepareLiquid({
    required String walletId,
    required String address,
    required RelativeFee feeRate,
    int? amountSat,
    bool drain = false,
    Set<Outpoint>? selectedInputs,
  }) async {
    asked.add(
      'prepare liquid $walletId $address ${feeRate.satPerKwu} $amountSat',
    );
    return liquid;
  }
}

PayinBuild<PayinSpend> _build(DepositTarget target) =>
    PayinBuild<PayinSpend>(payinOrder(), target, payinWalletSpend, 1);

void main() {
  test('an on-chain payin is prepared as the review chose: fee, '
      'replace-by-fee and the order amount to the deposit', () async {
    final spend = _Spend(bitcoin: const Err(SpendInsufficientFundsFailure()));
    final result = await BuildPayinUsecase(spend)
        .execute(_build(const OnchainDeposit('bc1q-deposit')));
    expect(
      result,
      isA<Err<PayinBuilt<PayinSpend>, ExchangePayinBuildFailure>>().having(
        (r) => r.failure.problem,
        'problem',
        PayinBuildProblem.insufficientFunds,
      ),
    );
    expect(spend.asked, [
      'prepare bitcoin w1 bc1q-deposit 100000 250 rbf=true inputs=null',
    ]);
  });

  test('a refused signature sends nothing and says why', () async {
    final spend = _Spend(
      bitcoin: Ok(
        SpendFixtures.preparedBitcoin(
          unsignedPsbt: 'psbt',
          fee: Sats.fromInt(300),
        ),
      ),
      signed: const Err(SpendSigningRefusedFailure()),
    );
    final result = await BuildPayinUsecase(spend).execute(_build(payinTarget));
    expect(
      result,
      isA<Err<PayinBuilt<PayinSpend>, ExchangePayinBuildFailure>>().having(
        (r) => r.failure.problem,
        'problem',
        PayinBuildProblem.signingRefused,
      ),
    );
    expect(spend.asked.last, 'sign bitcoin');
  });

  test('a Liquid payin is prepared at the network minimum fee', () async {
    final spend = _Spend(liquid: const Err(SpendUnavailableFailure()));
    final result = await BuildPayinUsecase(spend)
        .execute(_build(const LiquidDeposit('lq1-deposit')));
    expect(
      result,
      isA<Err<PayinBuilt<PayinSpend>, ExchangePayinBuildFailure>>().having(
        (r) => r.failure.problem,
        'problem',
        PayinBuildProblem.walletBusy,
      ),
    );
    expect(spend.asked, ['prepare liquid w1 lq1-deposit 25 100000']);
  });

  test('no app wallet pays a Lightning invoice', () async {
    final spend = _Spend();
    final result = await BuildPayinUsecase(spend)
        .execute(_build(const LightningInvoiceDeposit('lnbc1')));
    expect(
      result,
      isA<Err<PayinBuilt<PayinSpend>, ExchangePayinBuildFailure>>().having(
        (r) => r.failure.problem,
        'problem',
        PayinBuildProblem.invalid,
      ),
    );
    expect(spend.asked, isEmpty);
  });
}
