import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/exchange_support_chat/public/exchange_support_chat_facade.dart';
import 'package:bb_mobile/features/support/public/support_facade.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// No plugin is registered under `flutter test`, so url_launcher falls back to
// its method-channel implementation; record the URLs it is asked to open.
const _urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');

class _SupportTrigger extends StatelessWidget {
  const _SupportTrigger({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => SupportFacade.contactSupport(context, message: message),
      child: const Text('help'),
    );
  }
}

void main() {
  late List<Object?> launched;

  setUp(() {
    launched = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_urlLauncherChannel, (call) async {
          if (call.method == 'launch') {
            launched.add((call.arguments as Map<Object?, Object?>)['url']);
          }
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_urlLauncherChannel, null);
  });

  group('SupportFacade.contactSupport inside the router', () {
    late List<Object?> chatExtras;

    Future<GoRouter> pumpRouter(WidgetTester tester, {String? message}) async {
      chatExtras = [];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                Scaffold(body: _SupportTrigger(message: message)),
          ),
          GoRoute(
            name: ExchangeSupportChatFacade.routeName,
            path: '/support-chat',
            builder: (_, state) {
              chatExtras.add(state.extra);
              return const Scaffold(body: Text('chat'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      return router;
    }

    testWidgets('pushes the chat route with the draft message', (tester) async {
      final router = await pumpRouter(tester, message: 'Order 42');

      await tester.tap(find.text('help'));
      await tester.pumpAndSettle();

      expect(find.text('chat'), findsOneWidget);
      final draft = chatExtras.single;
      expect(draft, isA<ExchangeSupportChatDraft>());
      expect((draft as ExchangeSupportChatDraft).initialMessage, 'Order 42');
      expect(launched, isEmpty);

      // Pushed, not replaced: leaving the chat returns to the opener.
      expect(router.canPop(), isTrue);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('help'), findsOneWidget);
    });

    testWidgets('pushes the chat route without a draft when no message', (
      tester,
    ) async {
      await pumpRouter(tester);

      await tester.tap(find.text('help'));
      await tester.pumpAndSettle();

      expect(find.text('chat'), findsOneWidget);
      expect(chatExtras.single, isNull);
      expect(launched, isEmpty);
    });
  });

  group('SupportFacade.contactSupport outside the router', () {
    testWidgets('opens the web support page and does not navigate', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: _SupportTrigger(message: 'ignored')),
        ),
      );

      await tester.tap(find.text('help'));
      await tester.pumpAndSettle();

      expect(launched, [SettingsConstants.webSupportLink]);
      expect(find.text('help'), findsOneWidget);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(navigator.canPop(), isFalse);
    });
  });
}
