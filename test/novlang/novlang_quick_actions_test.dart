import 'package:bb_mobile/generated/novlang/novlang_quick_actions_localizations.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:novlang/novlang.dart';

/// The delegate as the app composes it: novlang on top of the fallback.
NovlangQuickActionsLocalizationsDelegate _delegate(NovlangPolicy policy) =>
    NovlangQuickActionsLocalizationsDelegate(
      policy,
      const QuickActionsFallbackDelegate(),
    );

class _MemoryStorage implements QuickActionsStorage {
  String? value;
  @override
  Future<String?> read(String key) async => value;
  @override
  Future<void> write(String key, String value) async => this.value = value;
  @override
  Future<void> remove(String key) async => value = null;
}

void main() {
  group('quick actions vocabulary per policy', () {
    for (final (locale, real, apple) in [
      (const Locale('en'), 'Swap', 'Transfer'),
      (const Locale('fr'), 'Échanger', 'Transférer'),
      // The feature catalogue falls back to English for other languages.
      (const Locale('de'), 'Swap', 'Transfer'),
    ]) {
      test('${locale.languageCode}: apple substitutes, others keep the '
          'real word', () async {
        for (final policy in [NovlangPolicy.none, NovlangPolicy.google]) {
          expect((await _delegate(policy).load(locale)).transfer, real);
        }
        expect(
          (await _delegate(NovlangPolicy.apple).load(locale)).transfer,
          apple,
        );
      });
    }

    test('keeps the fallback locale resolution and untouched keys', () async {
      final delegate = _delegate(NovlangPolicy.apple);
      expect(delegate.isSupported(const Locale('de')), isTrue);
      final de = await delegate.load(const Locale('de'));
      final none = await _delegate(NovlangPolicy.none).load(const Locale('de'));
      expect(de.localeName, 'en');
      expect(de.quickActionTrade, none.quickActionTrade);
      expect(de.map, 'Map');
      expect((await delegate.load(const Locale('fr'))).map, 'Carte');
    });
  });

  for (final (policy, label, absent) in [
    (NovlangPolicy.apple, 'Transfer', 'Swap'),
    (NovlangPolicy.none, 'Swap', 'Transfer'),
    (NovlangPolicy.google, 'Swap', 'Transfer'),
  ]) {
    testWidgets('the transfer quick action reads "$label" for $policy', (
      tester,
    ) async {
      final cubit = createQuickActionsCubit(
        storage: _MemoryStorage(),
        warning: (_) {},
        exchangeVisible: Stream.value(false),
      );
      addTearDown(cubit.close);
      QuickAction? chosen;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: testBullExtensions),
          localizationsDelegates: [_delegate(policy)],
          home: Scaffold(
            body: QuickActionsRow(
              cubit: cubit,
              onAction: (action) => chosen = action,
              onCustomize: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(absent), findsNothing);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(chosen, QuickAction.transfer);
    });
  }
}
