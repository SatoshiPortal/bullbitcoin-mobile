import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_ui/bull_ui.dart' show BullQuickAction, BullShapes;
import 'package:bull_ui/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'quick_actions_test.dart' show MemoryStorage;

const defaults = [
  QuickAction.map,
  QuickAction.transfer,
  QuickAction.history,
  QuickAction.settings,
];

Future<void> openEditor(
  WidgetTester tester,
  QuickActionsFacade facade, {
  Set<QuickAction>? available,
  Locale locale = const Locale('en'),
  double textScale = 1,
  bool dark = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('fr')],
      theme: ThemeData(
        brightness: dark ? Brightness.dark : Brightness.light,
        extensions: [
          dark
              ? testBullTheme.copyWith(
                  background: const Color(0xFF000000),
                  surface: const Color(0xFF171717),
                  surfaceContainerHighest: const Color(0xFF303030),
                  text: const Color(0xFFFFFFFF),
                )
              : testBullTheme,
          BullShapes.standard,
        ],
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child ?? const SizedBox.shrink(),
      ),
      localizationsDelegates: const [
        QuickActionsFallbackDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => QuickActionsCustomizationScreen(
                  facade: facade,
                  available: available ?? QuickAction.values.toSet(),
                  defaults: defaults,
                ),
              ),
            ),
            child: const Text('Open editor'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();
}

QuickActionsLocalizations localizations(WidgetTester tester) =>
    QuickActionsLocalizations.of(
      tester.element(find.byType(QuickActionsCustomizationScreen)),
    );

void main() {
  stressEditorTests();
  testWidgets('drag handle reorders favorites before explicit Save', (
    tester,
  ) async {
    final storage = MemoryStorage();
    await openEditor(
      tester,
      QuickActionsFacade(storage: storage, warning: (_) {}),
    );
    final l10n = localizations(tester);
    final handle = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == l10n.reorderAction(l10n.transfer),
    );
    final target = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == l10n.reorderAction(l10n.map),
    );
    expect(handle, findsOneWidget);
    expect(target, findsOneWidget);
    final handleRect = tester.getRect(handle);
    final targetRect = tester.getRect(target);
    expect(handleRect.height, 48);
    final gesture = await tester.startGesture(handleRect.center);
    await tester.pump();
    // Resolve the immediate drag recognizer before crossing the target row.
    await gesture.moveBy(const Offset(0, -24));
    await tester.pump(const Duration(milliseconds: 30));
    await gesture.moveTo(Offset(targetRect.center.dx, targetRect.top - 24));
    await tester.pump(const Duration(milliseconds: 350));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(storage.value, isNull);
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();
    expect(storage.value, '["transfer","map","history","settings"]');
  });
  testWidgets('preview, sections and fixed save explain the current layout', (
    tester,
  ) async {
    await openEditor(
      tester,
      QuickActionsFacade(storage: MemoryStorage(), warning: (_) {}),
    );
    final l10n = localizations(tester);
    expect(find.text(l10n.onHome), findsOneWidget);
    expect(find.text(l10n.inMore), findsOneWidget);
    expect(find.text(l10n.maximumHint), findsOneWidget);
    expect(find.text(l10n.overflowHint), findsOneWidget);
    final preview = find.byType(BullQuickAction);
    expect(preview, findsNWidgets(4));
    expect(
      tester
          .widgetList<BullQuickAction>(preview)
          .every((button) => button.disabled == false),
      isTrue,
    );
    final guard = find.ancestor(
      of: preview.first,
      matching: find.byType(IgnorePointer),
    );
    expect(tester.widget<IgnorePointer>(guard.first).ignoring, isTrue);
    final save = find.text(l10n.save);
    expect(
      tester.getRect(save).bottom,
      lessThanOrEqualTo(
        tester.view.physicalSize.height / tester.view.devicePixelRatio,
      ),
    );
    expect(find.textContaining('Move up:'), findsNothing);
  });

  testWidgets('add, reorder and remove retain explicit draft until save', (
    tester,
  ) async {
    final storage = MemoryStorage();
    await openEditor(
      tester,
      QuickActionsFacade(storage: storage, warning: (_) {}),
    );
    final l10n = localizations(tester);
    final addBuy = find.byTooltip(l10n.addAction(l10n.buy));
    await tester.ensureVisible(addBuy);
    await tester.tap(addBuy);
    await tester.pumpAndSettle();
    final buyHandle = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == l10n.reorderAction(l10n.buy),
    );
    await tester.ensureVisible(buyHandle);
    final semantics = tester.widget<Semantics>(buyHandle);
    final actions = semantics.properties.customSemanticsActions ?? {};
    final upBuy = actions.entries.singleWhere(
      (entry) => entry.key.label == '${l10n.moveUp}: ${l10n.buy}',
    );
    upBuy.value();
    await tester.pumpAndSettle();
    final removeMap = find.byTooltip(l10n.removeAction(l10n.map));
    await tester.ensureVisible(removeMap);
    await tester.tap(removeMap);
    await tester.pumpAndSettle();
    expect(storage.value, isNull);
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();
    expect(storage.value, '["transfer","history","buy","settings"]');
  });

  testWidgets('unavailable favorites survive editing and save', (tester) async {
    final storage = MemoryStorage()..value = '["buy","map","sell"]';
    final facade = QuickActionsFacade(storage: storage, warning: (_) {});
    await openEditor(tester, facade, available: defaults.toSet());
    final l10n = localizations(tester);
    expect(find.text(l10n.unavailable), findsNWidgets(2));
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();
    expect(storage.value, '["buy","map","sell"]');
  });

  testWidgets('empty selection can be saved and reset removes preference', (
    tester,
  ) async {
    final storage = MemoryStorage()..value = '["map"]';
    final facade = QuickActionsFacade(storage: storage, warning: (_) {});
    await openEditor(tester, facade, available: defaults.toSet());
    var l10n = localizations(tester);
    await tester.tap(find.byTooltip(l10n.removeAction(l10n.map)));
    await tester.pumpAndSettle();
    expect(find.text(l10n.emptyHint), findsOneWidget);
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();
    expect(storage.value, '[]');
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    l10n = localizations(tester);
    await tester.ensureVisible(find.text(l10n.reset));
    await tester.tap(find.text(l10n.reset));
    await tester.pumpAndSettle();
    expect(storage.value, isNull);
  });

  testWidgets('save failure remains next to the fixed save action', (
    tester,
  ) async {
    final storage = MemoryStorage()..failWrite = true;
    await openEditor(
      tester,
      QuickActionsFacade(storage: storage, warning: (_) {}),
    );
    final l10n = localizations(tester);
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();
    expect(find.text(l10n.saveFailed), findsOneWidget);
    expect(find.text(l10n.save), findsOneWidget);
    final failure = tester.getRect(find.text(l10n.saveFailed));
    final save = tester.getRect(find.text(l10n.save));
    expect(failure.bottom, lessThanOrEqualTo(save.top));
    expect(storage.value, isNull);
  });
}

void stressEditorTests() {
  for (final count in [0, 1, 4, 10]) {
    for (final locale in [const Locale('en'), const Locale('fr')]) {
      testWidgets(
        'editor $count favorites ${locale.languageCode} 320dp 200% keeps Save visible',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final storage = MemoryStorage()
            ..value =
                '[${QuickAction.values.take(count).map((a) => '"${a.id}"').join(',')}]';
          await openEditor(
            tester,
            QuickActionsFacade(storage: storage, warning: (_) {}),
            locale: locale,
            textScale: 2,
            dark: locale.languageCode == 'fr',
          );
          final l10n = localizations(tester);
          expect(tester.takeException(), isNull);
          final save = find.text(l10n.save);
          expect(tester.getRect(save).bottom, lessThanOrEqualTo(800));
          expect(tester.getRect(save).top, greaterThan(0));
          await tester.ensureVisible(find.text(l10n.reset));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(tester.getRect(save).bottom, lessThanOrEqualTo(800));
        },
      );
    }
  }
}
