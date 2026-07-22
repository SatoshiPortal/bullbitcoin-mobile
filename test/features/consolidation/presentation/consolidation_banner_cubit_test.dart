import 'package:bb_mobile/features/consolidation/domain/usecases/check_liquid_consolidation_usecase.dart';
import 'package:bb_mobile/features/consolidation/presentation/consolidation_banner_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCheckLiquidConsolidationUsecase extends Mock
    implements CheckLiquidConsolidationUsecase {}

void main() {
  late _MockCheckLiquidConsolidationUsecase check;

  const walletId = 'wallet-1';

  ConsolidationBannerCubit buildCubit() => ConsolidationBannerCubit(
    checkLiquidConsolidationUsecase: check,
    walletId: walletId,
  );

  setUp(() {
    check = _MockCheckLiquidConsolidationUsecase();
  });

  test('starts false before reload is ever called', () {
    final cubit = buildCubit();

    expect(cubit.state, isFalse);
  });

  test(
    'emits true when the use-case reports consolidation is required',
    () async {
      when(
        () => check.execute(walletId: walletId),
      ).thenAnswer((_) async => (utxoCount: 300, isRequired: true));
      final cubit = buildCubit();

      await cubit.reload();

      expect(cubit.state, isTrue);
    },
  );

  test('emits false when consolidation is not required', () async {
    when(
      () => check.execute(walletId: walletId),
    ).thenAnswer((_) async => (utxoCount: 3, isRequired: false));
    final cubit = buildCubit();

    await cubit.reload();

    expect(cubit.state, isFalse);
  });

  test(
    'keeps the last known value (best-effort) when the use-case throws',
    () async {
      when(
        () => check.execute(walletId: walletId),
      ).thenAnswer((_) async => (utxoCount: 300, isRequired: true));
      final cubit = buildCubit();
      await cubit.reload();
      expect(cubit.state, isTrue);

      when(
        () => check.execute(walletId: walletId),
      ).thenThrow(Exception('network down'));

      await cubit.reload();

      expect(cubit.state, isTrue); // unchanged, not reset to false
    },
  );

  test('does not emit after being closed', () async {
    when(
      () => check.execute(walletId: walletId),
    ).thenAnswer((_) async => (utxoCount: 300, isRequired: true));
    final cubit = buildCubit();
    await cubit.close();

    await cubit.reload();

    expect(cubit.isClosed, isTrue);
    expect(cubit.state, isFalse); // never emitted after close
  });
}
