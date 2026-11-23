import 'package:bb_mobile/features/pay/domain/prepare_pay_bitcoin_payin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/prepare_pay_liquid_payin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/sign_pay_payin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:fees/fees.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';
import 'package:spend/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bb_mobile/features/coins/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/wallet_utxo.dart';
import 'package:bb_mobile/features/pay/domain/load_pay_wallet_utxos_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWalletUtxosUsecase extends Mock
    implements GetWalletUtxosUsecase {}

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
  Future<Result<PreparedBitcoinSpend, PayFailure>> prepareBitcoin(
    _Spend spend,
  ) => PreparePayBitcoinPayinUsecase(spend).execute(
    walletId: 'source',
    address: "recipient",
    amountSat: 1000,
    networkFee: const RelativeFee(250),
  );

  Future<Result<PreparedLiquidSpend, PayFailure>> prepareLiquid(_Spend spend) =>
      PreparePayLiquidPayinUsecase(spend).execute(
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
      ) as Ok<PreparedBitcoinSpend, PayFailure>).value;
      expect(bitcoin, same(spend.bitcoin));
      expect(bitcoin.fee, Sats.fromInt(200));
      final signing = SignPayPayinUsecase(spend);
      final bitcoinSigned = (await signing.bitcoin(
        bitcoin,
      ) as Ok<SignedBitcoinSpend, PayFailure>).value;
      expect(spend.reviewed, same(bitcoin));
      expect(bitcoinSigned.txSize, 111);
      final liquid = (await prepareLiquid(
        spend,
      ) as Ok<PreparedLiquidSpend, PayFailure>).value;
      expect(liquid, same(spend.liquid));
      expect(liquid.fee, Sats.fromInt(25));
      final liquidSigned = (await signing.liquid(
        liquid,
      ) as Ok<SignedLiquidSpend, PayFailure>).value;
      expect(spend.reviewed, same(liquid));
      expect(liquidSigned.signedPset, 'signed');
    },
  );

  test('drain does not pass a fixed amount to Spend', () async {
    final spend = _Spend();
    final result = await PreparePayLiquidPayinUsecase(spend).execute(
      walletId: 'source',
      address: 'recipient',
      amountSat: 1000,
      feeRate: const RelativeFee(25),
      drain: true,
    );
    expect(result, isA<Ok<PreparedLiquidSpend, PayFailure>>());
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
        isA<PayInsufficientBalanceFailure>(),
      );
      expect(
        (await prepareLiquid(spend) as Err).failure,
        isA<PayInsufficientBalanceFailure>(),
      );
    });
  }

  test('native, fee and signature failures remain sanitized', () async {
    final spend = _Spend()..failure = const SpendInvalidTransactionFailure();
    final signing = SignPayPayinUsecase(spend);
    expect(
      (await prepareBitcoin(spend) as Err).failure,
      isA<PayUnexpectedFailure>(),
    );
    expect(
      (await prepareLiquid(spend) as Err).failure,
      isA<PayUnexpectedFailure>(),
    );
    expect(
      (await signing.bitcoin(spend.bitcoin) as Err).failure,
      isA<PayUnexpectedFailure>(),
    );
    expect(
      (await signing.liquid(spend.liquid) as Err).failure,
      isA<PayUnexpectedFailure>(),
    );
  });
  group('LoadPayWalletUtxosUsecase', () {
    test('a utxo read failure is a value, not a throw', () async {
      final utxos = _MockGetWalletUtxosUsecase();
      when(() => utxos.execute(walletId: any(named: 'walletId')))
          .thenThrow(Exception('public test transport failure'));

      final result = await LoadPayWalletUtxosUsecase(
        getWalletUtxosUsecase: utxos,
      ).execute(walletId: 'wallet-1');

      expect(
        (result as Err<List<WalletUtxo>, PayFailure>).failure,
        isA<PayUnexpectedFailure>(),
      );
    });
  });
}
