import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:bull_exchange/testing.dart';
import 'package:bull_ui/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _screen({required bool websiteOnly, required List<bool> actions}) =>
    MaterialApp(
      theme: ThemeData(extensions: testBullExtensions),
      locale: const Locale('en'),
      localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
      supportedLocales: ExchangeLocalizations.supportedLocales,
      home: ExchangeSettingsScreen(
        websiteOnly: websiteOnly,
        onOpenRecipients: () {},
        onOpenTransactions: () {},
        onOpenDefaultWallets: () {},
        onOpenExchange: () {},
        isLoggedIn: () => true,
        sessionChanges: () => const Stream.empty(),
        title: (_) => 'Exchange settings',
        signedOutMessage: (_) => '',
        buildAccountActions: (showDeleteAccount) {
          actions.add(showDeleteAccount);
          return const SizedBox.shrink();
        },
      ),
    );

void main() {
  // The screen gets the one predicate's answer; the platform it runs on
  // (Linux here) must not matter.
  for (final (platform, superuser) in [
    (ExchangePlatform.other, false),
    (ExchangePlatform.other, true),
    (ExchangePlatform.ios, true),
  ]) {
    testWidgets('$platform superuser=$superuser shows the account entries', (
      tester,
    ) async {
      final actions = <bool>[];
      await tester.pumpWidget(
        _screen(
          websiteOnly: platform.websiteOnly(isSuperuser: superuser),
          actions: actions,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Account Information'), findsOneWidget);
      expect(find.text('Referrals'), findsOneWidget);
      expect(actions.last, isFalse);
    });
  }

  testWidgets('iOS without superuser shows only the account actions', (
    tester,
  ) async {
    final actions = <bool>[];
    await tester.pumpWidget(
      _screen(
        websiteOnly: ExchangePlatform.ios.websiteOnly(isSuperuser: false),
        actions: actions,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Account Information'), findsNothing);
    expect(find.text('Referrals'), findsNothing);
    expect(actions.last, isTrue);
  });
}
