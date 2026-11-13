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
    when(
      () => exchange.enable(forSupport: true),
    ).thenAnswer((_) async => const Ok(null));
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
          builder: (_, _) => ExchangeSupportLoginScreen(draft: draft),
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
    verify(() => exchange.enable(forSupport: true)).called(1);
    expect(find.text('Authentication'), findsOneWidget);
    expect(receivedDraft, same(draft));
    expect(receivedSource, 'support');
  });
  testWidgets('support login is visible even when trading is restricted', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ExchangeSupportLoginScreen(),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ExchangeSupportLoginScreen));
    expect(
      find.text(AppLocalizations.of(context).exchangeLoginButton),
      findsOneWidget,
    );
  });
  testWidgets('activation failure stays on support and shows an error', (
    tester,
  ) async {
    final exchange = _Exchange();
    when(
      () => exchange.enable(forSupport: true),
    ).thenAnswer((_) async => const Err(ExchangeNetworkFailure()));
    locator.registerSingleton<ExchangeFacade>(exchange);
    addTearDown(() => locator.unregister<ExchangeFacade>());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ExchangeSupportLoginScreen(),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ExchangeSupportLoginScreen));
    final loc = AppLocalizations.of(context);
    await tester.tap(find.text(loc.exchangeLoginButton));
    await tester.pump();
    expect(find.text(loc.exchangeErrorNetwork), findsOneWidget);
    verify(() => exchange.enable(forSupport: true)).called(1);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
