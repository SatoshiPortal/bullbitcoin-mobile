import 'package:bull_ui/testing.dart' show testBullExtensions;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:swap_feature/src/presentation/swap_restore_cubit.dart';
import 'package:swap_feature/src/ui/swap_restore_screen.dart';
import 'package:swaps/swaps.dart';

class _RestoreCubit extends Mock implements SwapRestoreCubit {}

RestorableSwap _swap(String id, {required bool recoverable}) => RestorableSwap(
  swap: RestoredSwap(
    id: id,
    kind: RestoredSwapKind.crossChain,
    status: SwapStatus.pending,
    recoverable: recoverable,
    amountSat: 100,
    createdAt: DateTime.utc(2026),
    fromAsset: 'BTC',
    toAsset: 'L-BTC',
  ),
  existsLocally: false,
);

void main() {
  testWidgets('recovery rows expose one named button or plain text, and '
      'section titles are headers', (tester) async {
    final handle = tester.ensureSemantics();
    final cubit = _RestoreCubit();
    when(() => cubit.state).thenReturn(
      SwapRestoreState(
        status: SwapRestoreStatus.success,
        swaps: [
          _swap('actionable-1', recoverable: true),
          _swap('resolved-2', recoverable: false),
        ],
      ),
    );
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.close()).thenAnswer((_) async {});
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        home: BlocProvider<SwapRestoreCubit>.value(
          value: cubit,
          child: const SwapRestoreScreen(),
        ),
      ),
    );
    await tester.pump();

    final actionable = tester.getSemantics(
      find.bySemanticsLabel(RegExp('actionable-1')),
    );
    expect(actionable, isSemantics(isButton: true, hasTapAction: true));
    expect(actionable.label, contains('Cross Chain'));

    final resolved = tester.getSemantics(
      find.bySemanticsLabel(RegExp('resolved-2')),
    );
    expect(
      resolved,
      isNot(isSemantics(isButton: true)),
      reason: 'a resolved swap is read-only',
    );
    expect(resolved, isNot(isSemantics(hasTapAction: true)));

    for (final title in ['RECOVERABLE', 'ALL SWAPS']) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(title)),
        isSemantics(isHeader: true),
        reason: title,
      );
    }
    handle.dispose();
  });
}
