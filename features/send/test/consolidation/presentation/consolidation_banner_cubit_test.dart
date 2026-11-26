import 'package:primitives/primitives.dart';
import 'package:send/src/consolidation/domain/consolidation.dart';
import 'package:send/src/consolidation/presentation/consolidation_banner_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockConsolidation extends Mock implements Consolidation {}

void main() {
  late _MockConsolidation check;
  late ConsolidationBannerCubit cubit;

  const walletId = 'wallet-1';

  setUp(() {
    check = _MockConsolidation();
    cubit = ConsolidationBannerCubit(consolidation: check, walletId: walletId);
  });

  test('starts false before reload is ever called', () {
    expect(cubit.state, isFalse);
  });

  test(
    'emits true when the use-case reports consolidation is required',
    () async {
      when(() => check.isRequired(any()))
          .thenAnswer((_) async => const Ok(true));

      await cubit.reload();

      expect(cubit.state, isTrue);
    },
  );

  test('emits false when consolidation is not required', () async {
    when(() => check.isRequired(any()))
        .thenAnswer((_) async => const Ok(false));

    await cubit.reload();

    expect(cubit.state, isFalse);
  });

  test(
    'keeps the last known value (best-effort) when the use-case throws',
    () async {
      when(() => check.isRequired(any()))
          .thenAnswer((_) async => const Ok(true));
      await cubit.reload();
      expect(cubit.state, isTrue);

      when(() => check.isRequired(any())).thenThrow(Exception('read failed'));
      await cubit.reload();

      expect(cubit.state, isTrue);
    },
  );

  test('does not emit after being closed', () async {
    when(() => check.isRequired(any())).thenAnswer((_) async => const Ok(true));

    await cubit.close();
    await cubit.reload();

    expect(cubit.isClosed, isTrue);
    expect(cubit.state, isFalse);
  });
}
