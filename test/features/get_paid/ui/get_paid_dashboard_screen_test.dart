import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/get_paid/presentation/get_paid_dashboard_cubit.dart';
import 'package:bb_mobile/features/get_paid/presentation/get_paid_dashboard_state.dart';
import 'package:bb_mobile/features/get_paid/ui/screens/get_paid_dashboard_screen.dart';
import 'package:bb_mobile/features/get_paid/ui/widgets/get_paid_slot_card.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart' show BullShimmerBox, BullTopBar;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

// Stub cubit seeded with a fixed state; refresh() is a no-op so the seeded
// state renders without a locator or the real facades.
class _StubCubit extends Cubit<GetPaidDashboardState>
    implements GetPaidDashboardCubit {
  _StubCubit(super.initialState);

  @override
  Future<void> refresh() async {}
}

Future<void> _pump(WidgetTester tester, GetPaidDashboardState state) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: BlocProvider<GetPaidDashboardCubit>.value(
        value: _StubCubit(state),
        child: const GetPaidDashboardScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the hub renders its top bar and five slot cards', (
    tester,
  ) async {
    await _pump(tester, const GetPaidDashboardState());

    expect(find.byType(BullTopBar), findsOneWidget);
    expect(find.byType(GetPaidSlotCard), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the first load shows shimmer placeholders, not cards', (
    tester,
  ) async {
    await _pump(tester, const GetPaidDashboardState(isLoading: true));

    expect(find.byType(GetPaidSlotCard), findsNothing);
    expect(find.byType(BullShimmerBox), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });
}
