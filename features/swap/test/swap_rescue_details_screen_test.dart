import 'package:bull_ui/bull_ui.dart' show BullButton;
import 'package:bull_ui/testing.dart' show testBullExtensions;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:swap_feature/src/presentation/swap_rescue_cubit.dart';
import 'package:swap_feature/src/ui/swap_rescue_details_screen.dart';
import 'package:swaps/swaps.dart';

class _RescueCubit extends Mock implements SwapRescueCubit {}

RestorableSwap _restorable({
  required bool existsLocally,
  bool locallyUnresolved = false,
}) => RestorableSwap(
  swap: RestoredSwap(
    id: 'swap-1',
    kind: RestoredSwapKind.crossChain,
    status: SwapStatus.pending,
    recoverable: true,
    amountSat: 100,
    createdAt: DateTime.utc(2026),
    fromAsset: 'BTC',
    toAsset: 'L-BTC',
  ),
  existsLocally: existsLocally,
  locallyUnresolved: locallyUnresolved,
);

void main() {
  Future<BullButton> pumpButton(
    WidgetTester tester,
    RestorableSwap restorable,
  ) async {
    final cubit = _RescueCubit();
    when(() => cubit.state).thenReturn(
      const SwapRescueState(
        status: SwapRescueStatus.ready,
        selectedWalletId: 'wallet',
      ),
    );
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.close()).thenAnswer((_) async {});
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        home: BlocProvider<SwapRescueCubit>.value(
          value: cubit,
          child: SwapRescueDetailsScreen(restorable: restorable),
        ),
      ),
    );
    await tester.pump();
    return tester.widget<BullButton>(find.byType(BullButton));
  }

  testWidgets('a swap already resolved locally cannot be rescued', (
    tester,
  ) async {
    final button = await pumpButton(tester, _restorable(existsLocally: true));
    expect(button.disabled, isTrue);
  });

  testWidgets('a swap stuck locally can still be rescued', (tester) async {
    final button = await pumpButton(
      tester,
      _restorable(existsLocally: true, locallyUnresolved: true),
    );
    expect(button.disabled, isFalse);
  });

  testWidgets('a swap unknown locally can be rescued', (tester) async {
    final button = await pumpButton(tester, _restorable(existsLocally: false));
    expect(button.disabled, isFalse);
  });
}
