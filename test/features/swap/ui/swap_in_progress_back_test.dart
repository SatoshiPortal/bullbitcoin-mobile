import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/swap/ui/pages/swap_in_progress_page.dart';
import 'package:bb_mobile/features/swap/ui/swap_router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockTransferBloc extends Mock implements TransferBloc {}

void main() {
  testWidgets('system back on the transfer in progress page goes home', (
    tester,
  ) async {
    final bloc = _MockTransferBloc();
    when(() => bloc.state).thenReturn(const TransferState());
    when(
      () => bloc.stream,
    ).thenAnswer((_) => StreamController<TransferState>.broadcast().stream);

    // The real flow reaches this page with a `go`, which leaves the stack as
    // [/swap, /swap/in-progress] — the wallet home is gone from under it, so
    // popping lands on an orphan transfer page whose next back closes the app.
    // The transfer page itself is stubbed here; only the stack shape matters.
    final router = GoRouter(
      initialLocation: SwapRoute.swap.path,
      routes: [
        GoRoute(
          name: WalletRoute.walletHome.name,
          path: WalletRoute.walletHome.path,
          builder: (context, state) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          name: SwapRoute.swap.name,
          path: SwapRoute.swap.path,
          builder: (context, state) => const Scaffold(body: Text('transfer')),
          routes: [
            GoRoute(
              name: SwapRoute.inProgressSwap.name,
              path: SwapRoute.inProgressSwap.path,
              builder: (context, state) => BlocProvider<TransferBloc>.value(
                value: bloc,
                child: const SwapInProgressPage(),
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();

    // Exactly what the router does once the transfer is broadcast.
    router.goNamed(SwapRoute.inProgressSwap.name);
    await tester.pumpAndSettle();
    expect(find.byType(SwapInProgressPage), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      WalletRoute.walletHome.path,
    );
    expect(find.text('transfer'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });
}
