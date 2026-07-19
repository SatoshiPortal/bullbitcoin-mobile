import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/get_paid/presentation/get_paid_dashboard_cubit.dart';
import 'package:bb_mobile/features/get_paid/presentation/get_paid_dashboard_state.dart';
import 'package:bb_mobile/features/get_paid/ui/screens/get_paid_dashboard_screen.dart';
import 'package:bb_mobile/features/get_paid/ui/widgets/get_paid_slot_card.dart';
import 'package:bb_mobile/features/invoices/public/invoices_routes.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart' show BullTopBar;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

  testWidgets('the first load shows cards with in-card progress indicators', (
    tester,
  ) async {
    await _pump(tester, const GetPaidDashboardState(isLoading: true));

    expect(find.byType(GetPaidSlotCard), findsNWidgets(5));
    expect(find.byType(CircularProgressIndicator), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('only unresolved cards retain progress indicators', (
    tester,
  ) async {
    await _pump(
      tester,
      const GetPaidDashboardState(
        lightningStatus: GetPaidDashboardCardStatus.loaded,
        invoicesStatus: GetPaidDashboardCardStatus.loaded,
        btcpayStatus: GetPaidDashboardCardStatus.loaded,
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Invoices card opens invoice creation directly', (tester) async {
    final cubit = _StubCubit(const GetPaidDashboardState());
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              BlocProvider<GetPaidDashboardCubit>.value(
                value: cubit,
                child: const GetPaidDashboardScreen(),
              ),
        ),
        GoRoute(
          name: InvoicesRoute.create.name,
          path: '/invoice-create',
          builder: (context, state) =>
              const Scaffold(body: Text('invoice-create-destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Invoices'));
    await tester.pumpAndSettle();

    expect(find.text('invoice-create-destination'), findsOneWidget);
  });
}
