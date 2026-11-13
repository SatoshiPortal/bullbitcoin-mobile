import 'package:bb_mobile/features/exchange_support_chat/public/exchange_support_chat_facade.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_support_login_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _Exchange extends Mock implements ExchangeFacade {}

void main() {
  testWidgets('support login enables exchange before opening authentication', (
    tester,
  ) async {
    final exchange = _Exchange();
    when(() => exchange.enable()).thenAnswer((_) async => const Ok(null));
    locator.registerSingleton<ExchangeFacade>(exchange);
    addTearDown(() => locator.unregister<ExchangeFacade>());
    const draft = ExchangeSupportChatDraft(initialMessage: 'Help');
    Object? receivedDraft;
    String? receivedSource;
    final router = GoRouter(
      initialLocation: '/support',
      routes: [
        GoRoute(
          path: '/support',
          builder: (_, _) =>
              ExchangeSupportLoginScreen(draft: draft, canLogin: (_) => true),
        ),
        GoRoute(
          path: '/auth',
          name: ExchangeRoute.exchangeAuth.name,
          builder: (_, state) {
            receivedDraft = state.extra;
            receivedSource = state.uri.queryParameters['from'];
            return const Scaffold(body: Text('Authentication'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.themeData(AppThemeType.light),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ExchangeSupportLoginScreen));
    await tester.tap(
      find.text(AppLocalizations.of(context).exchangeLoginButton),
    );
    await tester.pumpAndSettle();
    verify(() => exchange.enable()).called(1);
    expect(find.text('Authentication'), findsOneWidget);
    expect(receivedDraft, same(draft));
    expect(receivedSource, 'support');
  });
  for (final allowed in [true, false]) {
    testWidgets(
      allowed
          ? 'activation failure stays on support and shows an error'
          : 'platform restriction hides login and never activates',
      (tester) async {
        final exchange = _Exchange();
        when(
          () => exchange.enable(),
        ).thenAnswer((_) async => const Err(ExchangeNetworkFailure()));
        locator.registerSingleton<ExchangeFacade>(exchange);
        addTearDown(() => locator.unregister<ExchangeFacade>());
        final router = GoRouter(
          initialLocation: '/support',
          routes: [
            GoRoute(
              path: '/support',
              builder: (_, _) =>
                  ExchangeSupportLoginScreen(canLogin: (_) => allowed),
            ),
            GoRoute(
              path: '/auth',
              name: ExchangeRoute.exchangeAuth.name,
              builder: (_, _) => const Scaffold(body: Text('Authentication')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.themeData(AppThemeType.light),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(ExchangeSupportLoginScreen));
        final loc = AppLocalizations.of(context);
        if (allowed) {
          await tester.tap(find.text(loc.exchangeLoginButton));
          await tester.pump();
          expect(find.text(loc.exchangeErrorNetwork), findsOneWidget);
          verify(() => exchange.enable()).called(1);
        } else {
          expect(find.text(loc.exchangeLoginButton), findsNothing);
          verifyNever(() => exchange.enable());
        }
        expect(find.text('Authentication'), findsNothing);
        if (allowed) {
          await tester.pump(const Duration(seconds: 4));
          await tester.pumpAndSettle();
        }
      },
    );
  }
}
