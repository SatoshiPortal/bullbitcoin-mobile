import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/features/sell/domain/usecases/prepare_sell_liquid_payin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockLiquidWalletRepository extends Mock
    implements LiquidWalletRepository {}

/// A reason of the shape LWK actually produces — it quotes the address, so it
/// must never travel into a user-facing message.
const _rawReason = 'LwkError: cannot fund lq1qsecretaddress0000';

void main() {
  late _MockLiquidWalletRepository repository;
  late PrepareSellLiquidPayinUsecase usecase;

  setUpAll(() {
    registerFallbackValue(const RelativeFee(25));
  });

  setUp(() {
    repository = _MockLiquidWalletRepository();
    usecase = PrepareSellLiquidPayinUsecase(liquidWalletRepository: repository);
  });

  Future<Result<String, SellFailure>> run({int? amountSat = 100000}) =>
      usecase.execute(
        walletId: 'wallet-1',
        address: 'lq1qdestination',
        feeRate: const RelativeFee(25),
        amountSat: amountSat,
      );

  void stubFailure(WalletFailure failure) {
    when(
      () => repository.buildPset(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        feeRate: any(named: 'feeRate'),
        drain: any(named: 'drain'),
      ),
    ).thenAnswer((_) async => Err(failure));
  }

  test('returns the built pset', () async {
    when(
      () => repository.buildPset(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        feeRate: any(named: 'feeRate'),
        drain: any(named: 'drain'),
      ),
    ).thenAnswer((_) async => const Ok('cHNldP8='));

    final result = await run();

    expect(result, isA<Ok<String, SellFailure>>());
    expect((result as Ok<String, SellFailure>).value, 'cHNldP8=');
  });

  test('a shortfall is named, not reported as an unexpected error', () async {
    // Before sell owned this boundary the exception reached the bloc's generic
    // catch and the user was told "Oops". A shortfall is actionable.
    stubFailure(const WalletInsufficientFundsFailure(_rawReason));

    final result = await run();

    switch (result) {
      case Ok():
        fail('a shortfall must not produce a spendable pset');
      case Err(:final failure):
        expect(failure, isA<SellInsufficientBalanceFailure>());
        expect(
          (failure as SellInsufficientBalanceFailure).requiredAmountSat,
          100000,
        );
    }
  });

  test('no spendable utxo reads as a shortfall too', () async {
    stubFailure(const WalletNoSpendableInputsFailure(_rawReason));

    final result = await run();

    expect(
      (result as Err<String, SellFailure>).failure,
      isA<SellInsufficientBalanceFailure>(),
    );
  });

  test('consolidation required is not a shortfall', () async {
    stubFailure(const WalletConsolidationRequiredFailure(_rawReason));

    final result = await run();

    final failure = (result as Err<String, SellFailure>).failure;
    expect(failure, isA<SellUnexpectedFailure>());
    expect(
      failure,
      isNot(isA<SellInsufficientBalanceFailure>()),
      reason: 'the wallet has the funds, they just need consolidating',
    );
  });

  test('any other LWK error is sanitized into the catch-all', () async {
    stubFailure(const WalletTransactionBuildFailure(_rawReason));

    final result = await run();

    final failure = (result as Err<String, SellFailure>).failure;
    expect(failure, isA<SellUnexpectedFailure>());
    // Raw SDK diagnostics do not cross into the feature failure.
    expect(failure.logMessage, isNull);
  });

  for (final error in <Object>[
    _rawReason,
    StateError('invalid wallet state'),
  ]) {
    test(
      error is String
          ? 'maps native initialization failures without exposing their message'
          : 'does not mask programmer errors as recoverable failures',
      () async {
        when(
          () => repository.buildPset(
            walletId: any(named: 'walletId'),
            address: any(named: 'address'),
            amountSat: any(named: 'amountSat'),
            feeRate: any(named: 'feeRate'),
            drain: any(named: 'drain'),
          ),
        ).thenAnswer((_) async => throw error);

        if (error is String) {
          final result = await run();
          final failure = (result as Err<String, SellFailure>).failure;
          expect(failure, isA<SellUnexpectedFailure>());
          expect(failure.logMessage, isNull);
        } else {
          await expectLater(run(), throwsA(same(error)));
        }
      },
    );
  }

  test('refuses to build without an amount and without drain', () async {
    final result = await run(amountSat: null);

    expect(result, isA<Err<String, SellFailure>>());
    verifyNever(
      () => repository.buildPset(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        feeRate: any(named: 'feeRate'),
        drain: any(named: 'drain'),
      ),
    );
  });
}
