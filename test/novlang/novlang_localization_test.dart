import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/novlang/novlang_app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novlang/novlang.dart';

Future<AppLocalizations> _load(NovlangPolicy policy, Locale locale) =>
    NovlangAppLocalizationsDelegate(policy).load(locale);

void main() {
  const en = Locale('en');

  group('vocabulary per policy', () {
    test(
      'catalogue words stay real when no store constraint applies',
      () async {
        for (final policy in [NovlangPolicy.none, NovlangPolicy.google]) {
          final loc = await _load(policy, en);
          expect(loc.coreSwapsChainExpired, 'Swap Expired');
          expect(loc.homeActionTransfer, 'Swap');
          expect(loc.systemLabelAutoSwap, 'Auto Swap');
          expect(loc.settingsExchangeSettingsTitle, 'Exchange Settings');
          expect(loc.sellExchangeRate, 'Exchange rate');
          expect(loc.sellRateExpired, 'Exchange rate expired. Refreshing…');
        }
      },
    );

    test('apple replaces swap, exchange and exchange rate', () async {
      final loc = await _load(NovlangPolicy.apple, en);
      expect(loc.coreSwapsChainExpired, 'Transfer Expired');
      expect(loc.homeActionTransfer, 'Transfer');
      expect(loc.swapTransferTitle, 'Transfer');
      expect(loc.systemLabelAutoSwap, 'Auto Transfer');
      expect(loc.settingsExchangeSettingsTitle, 'Account Settings');
      expect(loc.navigationTabExchange, 'Account');
      expect(loc.sellExchangeRate, 'Rate');
      expect(loc.sellRateExpired, 'Rate expired. Refreshing…');
      expect(loc.sellUpdatingRate, 'Updating rate…');
      expect(
        loc.bitcoinPriceExchangeRateUnavailable,
        'Rate unavailable. Please try again later.',
      );
    });

    test('messages keep their parameters and ICU branches', () async {
      final apple = await _load(NovlangPolicy.apple, en);
      final none = await _load(NovlangPolicy.none, en);
      expect(
        apple.swapErrorAmountBelowMinimum('1,000'),
        'Amount is below minimum transfer amount: 1,000 sats',
      );
      expect(
        none.swapErrorAmountBelowMinimum('1,000'),
        'Amount is below minimum swap amount: 1,000 sats',
      );
      expect(
        apple.sendErrorAmountAboveMaximum('9'),
        'Amount above maximum transfer limit: 9 sats',
      );
      expect(apple.swapRestoreActionable(0), 'No transfers to recover');
      expect(none.swapRestoreActionable(0), 'No swaps to recover');
      expect(
        apple.swapRestoreActionable(3),
        contains('recovering 3 transfers'),
      );
      expect(
        apple.swapUnderReviewSupportMessage('o1', 'r1', 7),
        contains('Order number: 7'),
      );
    });

    test('keys outside the manifest are never touched', () async {
      final apple = await _load(NovlangPolicy.apple, en);
      final none = await _load(NovlangPolicy.none, en);
      expect(apple.coreSwapsStatusPending, none.coreSwapsStatusPending);
      expect(apple.fundExchangeSepaTitle, none.fundExchangeSepaTitle);
      expect(apple.sellInteracTransfer, none.sellInteracTransfer);
    });

    test('regional locales follow their gen-l10n resolution', () async {
      final apple = await _load(NovlangPolicy.apple, const Locale('fr'));
      final none = await _load(NovlangPolicy.none, const Locale('fr'));
      expect(apple.coreSwapsChainExpired, isNot(none.coreSwapsChainExpired));
      expect(
        (await _load(NovlangPolicy.apple, const Locale('pt', 'BR'))).localeName,
        'pt_BR',
      );
      expect(
        (await _load(
          NovlangPolicy.apple,
          Locale.fromSubtags(languageCode: 'hi', scriptCode: 'Latn'),
        )).localeName,
        'hi_Latn',
      );
    });

    test('every supported locale loads an override for every policy', () async {
      for (final locale in AppLocalizations.supportedLocales) {
        final base = await _load(NovlangPolicy.none, locale);
        final apple = await _load(NovlangPolicy.apple, locale);
        expect(apple.localeName, base.localeName);
        expect(
          apple.coreSwapsChainExpired,
          isNot(contains(RegExp('swap', caseSensitive: false))),
          reason: '${locale.toLanguageTag()} leaks the forbidden word',
        );
      }
    });
  });

  group('policy selection', () {
    test(
      'iOS non-superuser gets the Apple vocabulary, superuser the real one',
      () async {
        for (final (superuser, expected) in [
          (null, 'Transfer Expired'),
          (false, 'Transfer Expired'),
          (true, 'Swap Expired'),
        ]) {
          final policy = resolveNovlangPolicy(TargetPlatform.iOS, superuser);
          expect(
            (await _load(policy, en)).coreSwapsChainExpired,
            expected,
            reason: 'iOS superuser=$superuser',
          );
        }
      },
    );

    test('Android always keeps the real words', () async {
      for (final superuser in [null, false, true]) {
        final policy = resolveNovlangPolicy(TargetPlatform.android, superuser);
        expect((await _load(policy, en)).coreSwapsChainExpired, 'Swap Expired');
      }
    });
  });

  testWidgets('toggling superuser swaps the words in place, both ways', (
    tester,
  ) async {
    final policy = ValueNotifier<NovlangPolicy>(NovlangPolicy.apple);
    var counterBuilds = 0;

    await tester.pumpWidget(
      ValueListenableBuilder<NovlangPolicy>(
        valueListenable: policy,
        builder: (context, value, _) => MaterialApp(
          locale: en,
          localizationsDelegates: [
            NovlangAppLocalizationsDelegate(value),
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                counterBuilds++;
                return Column(
                  children: [
                    Text(AppLocalizations.of(context).homeActionTransfer),
                    const _Counter(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Transfer'), findsOneWidget);

    await tester.tap(find.byType(_Counter));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    policy.value = NovlangPolicy.none;
    await tester.pumpAndSettle();
    expect(find.text('Swap'), findsOneWidget);
    expect(find.text('Transfer'), findsNothing);
    expect(find.text('1'), findsOneWidget, reason: 'state must survive');

    policy.value = NovlangPolicy.apple;
    await tester.pumpAndSettle();
    expect(find.text('Transfer'), findsOneWidget);
    expect(find.text('Swap'), findsNothing);
    expect(find.text('1'), findsOneWidget, reason: 'state must survive');
    expect(counterBuilds, greaterThan(1));
  });
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => _count++),
    child: Text('$_count'),
  );
}
