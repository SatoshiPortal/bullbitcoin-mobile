import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/consolidation_required_exception.dart';
import 'package:bb_mobile/core/wallet/domain/insufficient_funds_exception.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:bb_mobile/features/sell/domain/prepare_sell_liquid_payin_usecase.dart';
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

  void stubThrow(Object error) {
    when(
      () => repository.buildPset(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        feeRate: any(named: 'feeRate'),
        drain: any(named: 'drain'),
      ),
    ).thenThrow(error);
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
    ).thenAnswer((_) async => 'cHNldP8=');

    final result = await run();

    expect(result, isA<Ok<String, SellFailure>>());
    expect((result as Ok<String, SellFailure>).value, 'cHNldP8=');
  });

  test('a shortfall is named, not reported as an unexpected error', () async {
    // Before sell owned this boundary the exception reached the bloc's generic
    // catch and the user was told "Oops". A shortfall is actionable.
    stubThrow(InsufficientFundsException(_rawReason));

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
    stubThrow(NoSpendableUtxoException(_rawReason));

    final result = await run();

    expect(
      (result as Err<String, SellFailure>).failure,
      isA<SellInsufficientBalanceFailure>(),
    );
  });

  test('consolidation required is not a shortfall', () async {
    stubThrow(ConsolidationRequiredException(_rawReason));

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
    stubThrow(Exception(_rawReason));

    final result = await run();

    final failure = (result as Err<String, SellFailure>).failure;
    expect(failure, isA<SellUnexpectedFailure>());
    // The reason survives for the log only.
    expect(failure.logMessage, contains('LwkError'));
  });

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
