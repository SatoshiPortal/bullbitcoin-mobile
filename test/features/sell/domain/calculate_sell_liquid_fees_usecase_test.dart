import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/features/sell/domain/calculate_sell_liquid_fees_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockLiquidWalletRepository extends Mock
    implements LiquidWalletRepository {}

void main() {
  late _MockLiquidWalletRepository repository;
  late CalculateSellLiquidFeesUsecase usecase;

  setUp(() {
    repository = _MockLiquidWalletRepository();
    usecase = CalculateSellLiquidFeesUsecase(
      liquidWalletRepository: repository,
    );
  });

  test('returns the absolute fee, discarding the vsize', () async {
    when(
      () => repository.getPsetSizeAndAbsoluteFees(pset: any(named: 'pset')),
    ).thenAnswer((_) async => (1234, 250));

    final result = await usecase.execute(pset: 'pset');

    expect((result as Ok<int, SellFailure>).value, 250);
  });

  test('sanitizes an LWK error into the catch-all', () async {
    when(
      () => repository.getPsetSizeAndAbsoluteFees(pset: any(named: 'pset')),
    ).thenThrow(Exception('LwkError: bad pset lq1qsecret'));

    final result = await usecase.execute(pset: 'pset');

    switch (result) {
      case Ok():
        fail('an unreadable pset must not report a fee');
      case Err(:final failure):
        expect(failure, isA<SellUnexpectedFailure>());
        expect(failure.logMessage, contains('LwkError'));
    }
  });
}
