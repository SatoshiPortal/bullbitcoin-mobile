import 'package:bull_exchange/bull_exchange.dart';
import 'package:bull_exchange/src/support_chat/ui/exchange_support_chat_router.dart';
import 'package:bull_ui/bull_ui.dart' show BullUiLocalizations;
import 'package:bull_ui/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:primitives/primitives.dart';

Future<void> _pumpLogin(
  WidgetTester tester, {
  required Future<Result<void, ExchangeFailure>> Function() enable,
  required void Function(ExchangeSupportChatDraft?) onLogin,
  ExchangeSupportChatDraft? draft,
}) async {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, _) => const Scaffold()),
      ExchangeSupportChatRouter.route(
        exchange: () => fail('unexpected Exchange lookup'),
        isLoggedIn: (_) => false,
        enableLogin: (_) => enable(),
        onLogin: (_, draft) => onLogin(draft),
        loginLabel: (_) => 'Sign in',
        failureMessage: (_, failure) {
          expect(failure, isA<ExchangeNetworkFailure>());
          return 'Network unavailable';
        },
        onExit: (_, _) {},
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(extensions: testBullExtensions),
      locale: const Locale('en'),
      localizationsDelegates: const [
        BullUiLocalizations.delegate,
        ...ExchangeLocalizations.localizationsDelegates,
      ],
      supportedLocales: ExchangeLocalizations.supportedLocales,
    ),
  );
  await tester.pumpAndSettle();
  router.pushNamed(ExchangeSupportChatNavigation.routeName, extra: draft);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('support login enables exchange before opening authentication', (
    tester,
  ) async {
    var enableCalls = 0;
    const draft = ExchangeSupportChatDraft(initialMessage: 'Help');
    ExchangeSupportChatDraft? receivedDraft;
    await _pumpLogin(
      tester,
      draft: draft,
      enable: () async {
        enableCalls++;
        return const Ok(null);
      },
      onLogin: (draft) {
        expect(enableCalls, 1);
        receivedDraft = draft;
      },
    );
    expect(receivedDraft, isNull);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(receivedDraft, same(draft));
  });
  testWidgets('support login is visible even when trading is restricted', (
    tester,
  ) async {
    await _pumpLogin(
      tester,
      enable: () async => fail('unexpected activation'),
      onLogin: (_) => fail('unexpected navigation'),
    );
    expect(find.text('Sign in'), findsOneWidget);
  });
  testWidgets('activation failure stays on support and shows an error', (
    tester,
  ) async {
    var enableCalls = 0;
    await _pumpLogin(
      tester,
      enable: () async {
        enableCalls++;
        return const Err(ExchangeNetworkFailure());
      },
      onLogin: (_) => fail('unexpected navigation'),
    );
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Network unavailable'), findsOneWidget);
    expect(enableCalls, 1);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
