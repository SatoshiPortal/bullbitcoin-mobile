import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_pset_size_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLiquidWalletRepository extends Mock
    implements LiquidWalletRepository {}

void main() {
  late _MockLiquidWalletRepository repo;
  late CalculateLiquidPsetSizeUsecase usecase;

  setUp(() {
    repo = _MockLiquidWalletRepository();
    usecase = CalculateLiquidPsetSizeUsecase(liquidWalletRepository: repo);
  });

  test('returns the discounted vsize from the repository', () async {
    when(
      () => repo.getPsetSizeAndAbsoluteFees(pset: any(named: 'pset')),
    ).thenAnswer((_) async => (1234, 250));

    final result = await usecase.execute(pset: 'dummy-pset');

    expect(result, isA<Ok<int, SendFailure>>());
    expect((result as Ok<int, SendFailure>).value, 1234);
    verify(() => repo.getPsetSizeAndAbsoluteFees(pset: 'dummy-pset')).called(1);
  });

  test('sanitizes any underlying error into a build failure', () async {
    when(
      () => repo.getPsetSizeAndAbsoluteFees(pset: any(named: 'pset')),
    ).thenThrow(Exception('boom: bc1qsecretaddress'));

    final result = await usecase.execute(pset: 'dummy-pset');

    switch (result) {
      case Ok():
        fail('an LWK error must not be reported as a size');
      case Err(:final failure):
        expect(failure, isA<SendTransactionBuildFailure>());
        // The raw reason stays in the log-only slot, never in a user message.
        expect(failure.logMessage, contains('boom'));
    }
  });
}
