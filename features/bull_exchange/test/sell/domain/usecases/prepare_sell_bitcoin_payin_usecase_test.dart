import 'package:bull_exchange/src/sell/domain/usecases/prepare_sell_bitcoin_payin_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/prepare_sell_liquid_payin_usecase.dart';
import 'package:bull_exchange/src/sell/domain/usecases/sign_sell_payin_usecase.dart';
import 'package:bull_exchange/src/sell/domain/sell_failure.dart';
import 'package:fees/fees.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';
import 'package:spend/testing.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Spend extends FakeSpend {
  final bitcoin = SpendFixtures.preparedBitcoin(
    unsignedPsbt: 'psbt',
    fee: Sats.fromInt(200),
    txSize: 110,
  );
  final liquid = SpendFixtures.preparedLiquid(
    unsignedPset: 'pset',
    fee: Sats.fromInt(25),
    amountSent: Sats.fromInt(1000),
  );
  SpendFailure? failure;
  Object? reviewed;
  bool drainRequested = false;
  int? amountRequested;

  @override
  Future<Result<PreparedBitcoinSpend, SpendFailure>> prepareBitcoin({
    required String walletId,
    required List<BitcoinTransactionRecipient> recipients,
    required NetworkFee networkFee,
    Set<Outpoint>? selectedInputs,
    bool selectedOnly = false,
    bool replaceByFee = true,
  }) async => switch (failure) {
    final failure? => Err(failure),
    null => Ok(bitcoin),
  };

  @override
  Future<Result<PreparedLiquidSpend, SpendFailure>> prepareLiquid({
    required String walletId,
    required String address,
    required RelativeFee feeRate,
    int? amountSat,
    bool drain = false,
    Set<Outpoint>? selectedInputs,
  }) async {
    drainRequested = drain;
    amountRequested = amountSat;
    return switch (failure) {
      final failure? => Err(failure),
      null => Ok(liquid),
    };
  }

  @override
  Future<Result<SignedBitcoinSpend, SpendFailure>> signBitcoin({
    required PreparedBitcoinSpend prepared,
  }) async {
    reviewed = prepared;
    return switch (failure) {
      final failure? => Err(failure),
      null => Ok(SpendFixtures.signedBitcoin('signed', txSize: 111)),
    };
  }

  @override
  Future<Result<SignedLiquidSpend, SpendFailure>> signLiquid({
    required PreparedLiquidSpend prepared,
  }) async {
    reviewed = prepared;
    return switch (failure) {
      final failure? => Err(failure),
      null => Ok(SpendFixtures.signedLiquid('signed')),
    };
  }
}

void main() {
  Future<Result<PreparedBitcoinSpend, SellFailure>> prepareBitcoin(
    _Spend spend,
  ) => PrepareSellBitcoinPayinUsecase(spend).execute(
    walletId: 'source',
    recipients: [
      BitcoinTransactionRecipient.fixed(
        address: "recipient",
        amountSat: Sats.fromInt(1000),
      ),
    ],
    networkFee: const RelativeFee(250),
  );

  Future<Result<PreparedLiquidSpend, SellFailure>> prepareLiquid(
    _Spend spend,
  ) => PrepareSellLiquidPayinUsecase(spend).execute(
    walletId: 'source',
    address: 'recipient',
    amountSat: 1000,
    feeRate: const RelativeFee(25),
  );

  test(
    'reviews and signs the same preparation, including its real fee',
    () async {
      final spend = _Spend();
      final bitcoin = (await prepareBitcoin(
        spend,
      ) as Ok<PreparedBitcoinSpend, SellFailure>).value;
      expect(bitcoin, same(spend.bitcoin));
      expect(bitcoin.fee, Sats.fromInt(200));
      final signing = SignSellPayinUsecase(spend);
      final bitcoinSigned = (await signing.bitcoin(
        bitcoin,
      ) as Ok<SignedBitcoinSpend, SellFailure>).value;
      expect(spend.reviewed, same(bitcoin));
      expect(bitcoinSigned.txSize, 111);
      final liquid = (await prepareLiquid(
        spend,
      ) as Ok<PreparedLiquidSpend, SellFailure>).value;
      expect(liquid, same(spend.liquid));
      expect(liquid.fee, Sats.fromInt(25));
      final liquidSigned = (await signing.liquid(
        liquid,
      ) as Ok<SignedLiquidSpend, SellFailure>).value;
      expect(spend.reviewed, same(liquid));
      expect(liquidSigned.signedPset, 'signed');
    },
  );

  test('drain does not pass a fixed amount to Spend', () async {
    final spend = _Spend();
    final result = await PrepareSellLiquidPayinUsecase(spend).execute(
      walletId: 'source',
      address: 'recipient',
      amountSat: 1000,
      feeRate: const RelativeFee(25),
      drain: true,
    );
    expect(result, isA<Ok<PreparedLiquidSpend, SellFailure>>());
    expect(spend.drainRequested, isTrue);
    expect(spend.amountRequested, isNull);
  });

  for (final failure in <SpendFailure>[
    const SpendInsufficientFundsFailure(),
    const SpendNoSpendableInputsFailure(),
  ]) {
    test('$failure is a typed balance failure for either chain', () async {
      final spend = _Spend()..failure = failure;
      expect(
        (await prepareBitcoin(spend) as Err).failure,
        isA<SellInsufficientBalanceFailure>(),
      );
      expect(
        (await prepareLiquid(spend) as Err).failure,
        isA<SellInsufficientBalanceFailure>(),
      );
    });
  }

  test('native, fee and signature failures remain sanitized', () async {
    final spend = _Spend()..failure = const SpendInvalidTransactionFailure();
    final signing = SignSellPayinUsecase(spend);
    expect(
      (await prepareBitcoin(spend) as Err).failure,
      isA<SellUnexpectedFailure>(),
    );
    expect(
      (await prepareLiquid(spend) as Err).failure,
      isA<SellUnexpectedFailure>(),
    );
    expect(
      (await signing.bitcoin(spend.bitcoin) as Err).failure,
      isA<SellUnexpectedFailure>(),
    );
    expect(
      (await signing.liquid(spend.liquid) as Err).failure,
      isA<SellUnexpectedFailure>(),
    );
  });
}
