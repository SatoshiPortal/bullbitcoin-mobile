import 'package:bull_exchange/bull_exchange.dart';
import 'package:bull_exchange/src/withdraw/presentation/withdraw_bloc.dart';
import 'package:bull_exchange/src/withdraw/ui/screens/withdraw_success_screen.dart';
import 'package:bull_ui/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _MockWithdrawBloc extends Mock implements WithdrawBloc {}

class _MockWithdrawOrder extends Mock implements WithdrawOrder {}

void main() {
  testWidgets('success opens its order and system back closes the flow', (
    tester,
  ) async {
    final bloc = _MockWithdrawBloc();
    final order = _MockWithdrawOrder();
    when(() => order.orderId).thenReturn('order-1');
    when(() => bloc.state).thenReturn(WithdrawState.success(order: order));
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

    String? opened;
    final router = GoRouter(
      initialLocation: BullExchangeNavigation.dashboardPath,
      routes: [
        GoRoute(
          name: BullExchangeNavigation.dashboardName,
          path: BullExchangeNavigation.dashboardPath,
          builder: (_, _) => const Scaffold(body: Text('dashboard')),
        ),
        GoRoute(
          path: '/flow',
          builder: (_, _) => const Scaffold(body: Text('flow')),
        ),
        GoRoute(
          path: '/success',
          builder: (_, _) => BlocProvider<WithdrawBloc>.value(
            value: bloc,
            child: WithdrawSuccessScreen(openOrder: (_, id) => opened = id),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
        supportedLocales: ExchangeLocalizations.supportedLocales,
      ),
    );
    router.push('/flow');
    await tester.pumpAndSettle();
    router.push('/success');
    await tester.pumpAndSettle();
    final labels = ExchangeLocalizations.of(
      tester.element(find.byType(WithdrawSuccessScreen)),
    );
    await tester.tap(find.text(labels.withdrawSuccessOrderDetails));
    expect(opened, 'order-1');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('flow'), findsNothing);
    expect(find.text('dashboard'), findsOneWidget);
  });
}
