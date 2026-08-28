import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/screens/transaction_details_screen.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockTransactionDetailsCubit extends Mock
    implements TransactionDetailsCubit {}

/// Shaped like the real router for the routes that matter here: the details
/// screen is a top-level route, so a flow that `go`es to it on completion
/// leaves it alone on the stack with nothing to pop.
GoRouter _router({required String initialLocation}) {
  final cubit = _MockTransactionDetailsCubit();
  when(() => cubit.state).thenReturn(const TransactionDetailsState());
  when(() => cubit.stream).thenAnswer(
    (_) => StreamController<TransactionDetailsState>.broadcast().stream,
  );

  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        name: WalletRoute.walletHome.name,
        path: WalletRoute.walletHome.path,
        builder: (context, state) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        name: TransactionsRoute.orderSwapTransactionDetails.name,
        path: TransactionsRoute.orderSwapTransactionDetails.path,
        builder: (context, state) =>
            BlocProvider<TransactionDetailsCubit>.value(
              value: cubit,
              child: const TransactionDetailsScreen(),
            ),
      ),
    ],
  );
}

/// The loading skeletons animate forever, so pumpAndSettle would time out —
/// pump enough frames to run a route transition instead.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _pump(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
  await _frames(tester);
}

void main() {
  testWidgets('system back on a returnHome details screen goes home, not out', (
    tester,
  ) async {
    final router = _router(
      initialLocation: '/transaction/order-swap/local-1?returnHome=true',
    );
    await _pump(tester, router);
    expect(find.byType(TransactionDetailsScreen), findsOneWidget);

    // false means nothing handled the back and the framework falls through to
    // SystemNavigator.pop() — the app closing, which is issue #2511.
    final handled = await tester.binding.handlePopRoute();
    await _frames(tester);

    expect(handled, isTrue);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      WalletRoute.walletHome.path,
    );
  });

  testWidgets('system back still pops when the screen was pushed', (
    tester,
  ) async {
    final router = _router(initialLocation: WalletRoute.walletHome.path);
    await _pump(tester, router);

    router.pushNamed(
      TransactionsRoute.orderSwapTransactionDetails.name,
      pathParameters: {'localId': 'local-1'},
    );
    await _frames(tester);
    expect(find.byType(TransactionDetailsScreen), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await _frames(tester);

    expect(handled, isTrue);
    expect(find.byType(TransactionDetailsScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a pushed returnHome screen still pops one step, not home', (
    tester,
  ) async {
    final router = _router(initialLocation: WalletRoute.walletHome.path);
    await _pump(tester, router);

    // Reached the way the send and exchange flows do it: pushed on top of a
    // screen the user should come back to. returnHome only redirects the ✕.
    router.pushNamed(
      TransactionsRoute.orderSwapTransactionDetails.name,
      pathParameters: {'localId': 'local-1'},
      queryParameters: {'returnHome': 'true'},
    );
    await _frames(tester);
    expect(find.byType(TransactionDetailsScreen), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await _frames(tester);

    expect(handled, isTrue);
    expect(find.byType(TransactionDetailsScreen), findsNothing);
  });
}
