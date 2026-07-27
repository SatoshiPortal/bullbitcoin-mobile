import 'package:bb_mobile/core/wallet/domain/usecases/check_liquid_consolidation_usecase.dart';
import 'package:bb_mobile/features/consolidation/presentation/consolidation_banner_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCheckLiquidConsolidationUsecase extends Mock
    implements CheckLiquidConsolidationUsecase {}

void main() {
  late _MockCheckLiquidConsolidationUsecase check;
  late ConsolidationBannerCubit cubit;

  const walletId = 'wallet-1';

  setUp(() {
    check = _MockCheckLiquidConsolidationUsecase();
    cubit = ConsolidationBannerCubit(
      checkLiquidConsolidationUsecase: check,
      walletId: walletId,
    );
  });

  test('starts false before reload is ever called', () {
    expect(cubit.state, isFalse);
  });

  test(
    'emits true when the use-case reports consolidation is required',
    () async {
      when(
        () => check.execute(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async => true);

      await cubit.reload();

      expect(cubit.state, isTrue);
    },
  );

  test('emits false when consolidation is not required', () async {
    when(
      () => check.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => false);

    await cubit.reload();

    expect(cubit.state, isFalse);
  });

  test(
    'keeps the last known value (best-effort) when the use-case throws',
    () async {
      when(
        () => check.execute(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async => true);
      await cubit.reload();
      expect(cubit.state, isTrue);

      when(
        () => check.execute(walletId: any(named: 'walletId')),
      ).thenThrow(Exception('read failed'));
      await cubit.reload();

      expect(cubit.state, isTrue);
    },
  );

  test('does not emit after being closed', () async {
    when(
      () => check.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => true);

    await cubit.close();
    await cubit.reload();

    expect(cubit.isClosed, isTrue);
    expect(cubit.state, isFalse);
  });
}
