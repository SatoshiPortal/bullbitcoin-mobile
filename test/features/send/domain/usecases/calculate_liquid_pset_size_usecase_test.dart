import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/features/send/domain/domain_errors.dart';
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

    final vsize = await usecase.execute(pset: 'dummy-pset');

    expect(vsize, 1234);
    verify(() => repo.getPsetSizeAndAbsoluteFees(pset: 'dummy-pset')).called(1);
  });

  test(
    'maps any underlying error to CalculateLiquidPsetSizeException',
    () async {
      when(
        () => repo.getPsetSizeAndAbsoluteFees(pset: any(named: 'pset')),
      ).thenThrow(Exception('boom'));

      expect(
        () => usecase.execute(pset: 'dummy-pset'),
        throwsA(isA<CalculateLiquidPsetSizeException>()),
      );
    },
  );
}
