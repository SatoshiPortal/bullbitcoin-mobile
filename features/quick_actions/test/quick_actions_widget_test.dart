import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_ui/testing.dart';
import 'package:bull_ui/bull_ui.dart' show BullQuickAction;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quick_actions_test.dart' show MemoryStorage;

void main() {
  testWidgets('More shows the complement and dispatches the chosen action', (
    tester,
  ) async {
    final facade = QuickActionsFacade(
      storage: MemoryStorage(),
      warning: (_) {},
    );
    QuickAction? chosen;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: const [QuickActionsLocalizations.delegate],
        home: Scaffold(
          body: QuickActionsRow(
            facade: facade,
            available: QuickAction.values.toSet(),
            defaults: const [
              QuickAction.map,
              QuickAction.transfer,
              QuickAction.history,
              QuickAction.settings,
            ],
            onAction: (action) => chosen = action,
            onCustomize: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('More'), findsOneWidget);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Trade'), findsOneWidget);
    await tester.tap(find.text('Buy'));
    await tester.pumpAndSettle();
    expect(chosen, QuickAction.buy);
  });

  testWidgets('More is absent when there is no complement', (tester) async {
    final facade = QuickActionsFacade(
      storage: MemoryStorage(),
      warning: (_) {},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: const [QuickActionsLocalizations.delegate],
        home: Scaffold(
          body: QuickActionsRow(
            facade: facade,
            available: const {
              QuickAction.map,
              QuickAction.transfer,
              QuickAction.history,
              QuickAction.settings,
            },
            defaults: const [
              QuickAction.map,
              QuickAction.transfer,
              QuickAction.history,
              QuickAction.settings,
            ],
            onAction: (_) {},
            onCustomize: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('More'), findsNothing);
  });

  testWidgets('customization saves the edited selection', (tester) async {
    final storage = MemoryStorage();
    final facade = QuickActionsFacade(storage: storage, warning: (_) {});
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: const [QuickActionsLocalizations.delegate],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => QuickActionsCustomizationScreen(
                    facade: facade,
                    available: QuickAction.values.toSet(),
                    defaults: const [
                      QuickAction.map,
                      QuickAction.transfer,
                      QuickAction.history,
                      QuickAction.settings,
                    ],
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove Settings from favorites'), findsOneWidget);
    expect(find.byTooltip('Remove Map from favorites'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove Map from favorites'));
    await tester.pumpAndSettle();
    final addBuy = find.byTooltip('Add Buy to favorites');
    await tester.ensureVisible(addBuy);
    await tester.tap(addBuy);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(storage.value, '["transfer","history","settings","buy"]');
  });

  testWidgets('four cells stay on one line at 360 pixels with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final facade = QuickActionsFacade(
      storage: MemoryStorage(),
      warning: (_) {},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: const [QuickActionsLocalizations.delegate],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: Scaffold(
          body: QuickActionsRow(
            facade: facade,
            available: QuickAction.values.toSet(),
            defaults: const [
              QuickAction.map,
              QuickAction.transfer,
              QuickAction.history,
              QuickAction.settings,
            ],
            onAction: (_) {},
            onCustomize: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final buttons = find.byType(BullQuickAction);
    expect(buttons, findsNWidgets(4));
    final y = tester.getCenter(buttons.first).dy;
    for (var index = 1; index < 4; index++) {
      expect(tester.getCenter(buttons.at(index)).dy, closeTo(y, 0.01));
    }
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final locale in [const Locale('es'), const Locale('fr')]) {
    testWidgets('localizations support ${locale.languageCode}', (tester) async {
      final facade = QuickActionsFacade(
        storage: MemoryStorage(),
        warning: (_) {},
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: testBullExtensions),
          locale: locale,
          supportedLocales: const [Locale('es'), Locale('fr')],
          localizationsDelegates: const [
            QuickActionsFallbackDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: QuickActionsRow(
              facade: facade,
              available: const {QuickAction.map},
              defaults: const [QuickAction.map],
              onAction: (_) {},
              onCustomize: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(locale.languageCode == 'fr' ? 'Carte' : 'Map'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
