import 'dart:async';

import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullQuickAction, BullShapes, BullSnackBar;
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

Future<void> clearNotice(WidgetTester tester) async {
  BullSnackBar.dismiss();
  await tester.pumpAndSettle();
}

IconButton actionButton(WidgetTester tester, String tooltip) =>
    tester.widget<IconButton>(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == tooltip,
      ),
    );

void main() {
  stressEditorTests();
  testWidgets('drag immediately saves the three Home actions', (tester) async {
    final storage = MemoryStorage();
    await openEditor(
      tester,
      QuickActionsFacade(storage: storage, warning: (_) {}),
    );
    final l10n = localizations(tester);
    Finder handle(String label) => find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == l10n.reorderAction(label),
    );
    final from = tester.getRect(handle(l10n.transfer));
    final to = tester.getRect(handle(l10n.map));
    expect(from.height, 48);
    final gesture = await tester.startGesture(from.center);
    await tester.pump();
    await gesture.moveBy(const Offset(0, -24));
    await tester.pump(const Duration(milliseconds: 30));
    await gesture.moveTo(Offset(to.center.dx, to.top - 24));
    await tester.pump(const Duration(milliseconds: 350));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(storage.value, '["transfer","map","history"]');
    expect(find.byType(QuickActionsCustomizationScreen), findsOneWidget);
  });

  for (final locale in ['en', 'fr']) {
    testWidgets('two sections and a secondary fixed reset in $locale', (
      tester,
    ) async {
      final storage = MemoryStorage();
      await openEditor(
        tester,
        QuickActionsFacade(storage: storage, warning: (_) {}),
        locale: Locale(locale),
      );
      final l10n = localizations(tester);
      expect(find.text(l10n.onHome), findsOneWidget);
      expect(find.text(l10n.inMore), findsOneWidget);
      expect(find.text(l10n.homeFullHint), findsOneWidget);
      expect(find.text(l10n.reset), findsOneWidget);
      expect(find.text('Save changes'), findsNothing);
      expect(find.text('These favorites appear in More'), findsNothing);
      expect(storage.value, isNull);
      final reset = tester.widget<BullButton>(find.byType(BullButton));
      expect(reset.outlined, isTrue);
      expect(
        tester.getRect(find.text(l10n.reset)).bottom,
        lessThanOrEqualTo(
          tester.view.physicalSize.height / tester.view.devicePixelRatio,
        ),
      );
      expect(find.byType(BullQuickAction), findsNWidgets(4));
    });
  }

  testWidgets('plus is disabled at three and removal opens one slot', (
    tester,
  ) async {
    final storage = _EditorStorage();
    await openEditor(
      tester,
      QuickActionsFacade(storage: storage, warning: (_) {}),
    );
    final l10n = localizations(tester);
    final buy = find.byTooltip(l10n.addAction(l10n.buy));
    expect(actionButton(tester, l10n.addAction(l10n.buy)).onPressed, isNull);
    await tester.tap(find.byTooltip(l10n.removeAction(l10n.map)));
    await tester.pumpAndSettle();
    expect(storage.value, '["transfer","history"]');
    expect(find.text(l10n.homeFullHint), findsNothing);
    expect(actionButton(tester, l10n.addAction(l10n.buy)).onPressed, isNotNull);
    await tester.ensureVisible(buy);
    await tester.tap(buy);
    await tester.pumpAndSettle();
    expect(storage.value, '["transfer","history","buy"]');
    expect(storage.writes, 2);
    expect(actionButton(tester, l10n.addAction(l10n.sell)).onPressed, isNull);
  });

  testWidgets('each add and remove persists without a Save action', (
    tester,
  ) async {
    final storage = _EditorStorage()..value = '["map","transfer"]';
    await openEditor(
      tester,
      QuickActionsFacade(storage: storage, warning: (_) {}),
    );
    final l10n = localizations(tester);
    final add = find.byTooltip(l10n.addAction(l10n.buy));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(storage.value, '["map","transfer","buy"]');
    final remove = find.byTooltip(l10n.removeAction(l10n.buy));
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(storage.value, '["map","transfer"]');
    expect(storage.writes, 2);
  });

  testWidgets('failed write rolls back and shows saveFailed in a SnackBar', (
    tester,
  ) async {
    final storage = _EditorStorage()
      ..value = '["map","transfer"]'
      ..failWrite = true;
    await openEditor(
      tester,
      QuickActionsFacade(storage: storage, warning: (_) {}),
    );
    final l10n = localizations(tester);
    try {
      await tester.tap(find.byTooltip(l10n.removeAction(l10n.map)));
      await tester.pumpAndSettle();
      expect(storage.value, '["map","transfer"]');
      expect(find.text(l10n.map), findsNWidgets(2));
      expect(find.text(l10n.saveFailed), findsOneWidget);
      storage.failWrite = false;
      await tester.tap(find.byTooltip(l10n.removeAction(l10n.map)));
      await tester.pumpAndSettle();
      expect(storage.value, '["transfer"]');
    } finally {
      await clearNotice(tester);
    }
  });

  testWidgets(
    'Restore defaults persists immediately and Undo restores the complete previous list',
    (tester) async {
      final original = '["buy","map","transfer","history"]';
      final storage = _EditorStorage()..value = original;
      final facade = QuickActionsFacade(storage: storage, warning: (_) {});
      await openEditor(tester, facade, available: defaults.toSet());
      final l10n = localizations(tester);
      try {
        await tester.tap(find.text(l10n.reset));
        await tester.pumpAndSettle();
        expect(storage.value, isNull);
        expect(facade.selection, isNull);
        expect(find.byType(QuickActionsCustomizationScreen), findsOneWidget);
        expect(find.text(l10n.defaultsRestored), findsOneWidget);
        await tester.tap(find.text(l10n.undo));
        await tester.pumpAndSettle();
        expect(storage.value, original);
        expect(facade.selection?.actions.first, QuickAction.buy);
      } finally {
        await clearNotice(tester);
      }
    },
  );

  for (final previous in <String?>[null, '[]']) {
    testWidgets(
      'Undo preserves automatic versus explicitly empty preference $previous',
      (tester) async {
        final storage = _EditorStorage()..value = previous;
        await openEditor(
          tester,
          QuickActionsFacade(storage: storage, warning: (_) {}),
        );
        final l10n = localizations(tester);
        try {
          await tester.tap(find.text(l10n.reset));
          await tester.pumpAndSettle();
          expect(storage.value, isNull);
          await tester.tap(find.text(l10n.undo));
          await tester.pumpAndSettle();
          expect(storage.value, previous);
        } finally {
          await clearNotice(tester);
        }
      },
    );
  }

  testWidgets('failed reset keeps the old selection and offers no Undo', (
    tester,
  ) async {
    final storage = _EditorStorage()
      ..value = '["buy"]'
      ..failRemove = true;
    await openEditor(
      tester,
      QuickActionsFacade(storage: storage, warning: (_) {}),
    );
    final l10n = localizations(tester);
    try {
      await tester.tap(find.text(l10n.reset));
      await tester.pumpAndSettle();
      expect(storage.value, '["buy"]');
      expect(find.text(l10n.saveFailed), findsOneWidget);
      expect(find.text(l10n.undo), findsNothing);
    } finally {
      await clearNotice(tester);
    }
  });

  testWidgets('failed Undo stays at defaults and reports the write error', (
    tester,
  ) async {
    final storage = _EditorStorage()..value = '["buy"]';
    await openEditor(
      tester,
      QuickActionsFacade(storage: storage, warning: (_) {}),
    );
    final l10n = localizations(tester);
    try {
      await tester.tap(find.text(l10n.reset));
      await tester.pumpAndSettle();
      storage.failWrite = true;
      await tester.tap(find.text(l10n.undo));
      await tester.pumpAndSettle();
      expect(storage.value, isNull);
      expect(find.text(l10n.map), findsNWidgets(2));
      expect(find.text(l10n.saveFailed), findsOneWidget);
    } finally {
      await clearNotice(tester);
    }
  });

  testWidgets(
    'controls wait for an in-flight write and do not write concurrently',
    (tester) async {
      final gate = Completer<void>();
      final storage = _EditorStorage()
        ..value = '["map","transfer"]'
        ..gate = gate;
      await openEditor(
        tester,
        QuickActionsFacade(storage: storage, warning: (_) {}),
      );
      final l10n = localizations(tester);
      await tester.tap(find.byTooltip(l10n.removeAction(l10n.map)));
      await tester.pump();
      expect(storage.writes, 1);
      expect(storage.value, '["map","transfer"]');
      expect(actionButton(tester, l10n.addAction(l10n.buy)).onPressed, isNull);
      expect(
        tester.widget<BullButton>(find.byType(BullButton)).disabled,
        isTrue,
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(storage.value, '["transfer"]');
      expect(storage.maximumInFlight, 1);
    },
  );

  testWidgets('pending save survives closing the editor', (tester) async {
    final gate = Completer<void>();
    final storage = _EditorStorage()
      ..value = '["map","transfer"]'
      ..gate = gate;
    final facade = QuickActionsFacade(storage: storage, warning: (_) {});
    await openEditor(tester, facade);
    final l10n = localizations(tester);
    await tester.tap(find.byTooltip(l10n.removeAction(l10n.map)));
    await tester.pump();
    Navigator.of(
      tester.element(find.byType(QuickActionsCustomizationScreen)),
    ).pop();
    await tester.pumpAndSettle();
    gate.complete();
    await tester.pumpAndSettle();
    expect(storage.value, '["transfer"]');
    expect(facade.selection?.actions, [QuickAction.transfer]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed pending save reports on the root overlay after closing', (
    tester,
  ) async {
    final gate = Completer<void>();
    final storage = _EditorStorage()
      ..value = '["map","transfer"]'
      ..gate = gate
      ..failWrite = true;
    await openEditor(
      tester,
      QuickActionsFacade(storage: storage, warning: (_) {}),
    );
    final l10n = localizations(tester);
    try {
      await tester.tap(find.byTooltip(l10n.removeAction(l10n.map)));
      await tester.pump();
      Navigator.of(
        tester.element(find.byType(QuickActionsCustomizationScreen)),
      ).pop();
      await tester.pumpAndSettle();
      gate.complete();
      await tester.pumpAndSettle();
      expect(storage.value, '["map","transfer"]');
      expect(find.text(l10n.saveFailed), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await clearNotice(tester);
    }
  });

  testWidgets('Undo remains functional after closing the editor', (
    tester,
  ) async {
    final storage = _EditorStorage()..value = '["buy"]';
    await openEditor(
      tester,
      QuickActionsFacade(storage: storage, warning: (_) {}),
    );
    final l10n = localizations(tester);
    try {
      await tester.tap(find.text(l10n.reset));
      await tester.pumpAndSettle();
      Navigator.of(
        tester.element(find.byType(QuickActionsCustomizationScreen)),
      ).pop();
      await tester.pumpAndSettle();
      expect(storage.value, isNull);
      await tester.tap(find.text(l10n.undo));
      await tester.pumpAndSettle();
      expect(storage.value, '["buy"]');
      expect(tester.takeException(), isNull);
    } finally {
      await clearNotice(tester);
    }
  });

  testWidgets('Undo cannot overwrite a newer confirmed preference', (
    tester,
  ) async {
    final storage = _EditorStorage()..value = '["buy"]';
    final facade = QuickActionsFacade(storage: storage, warning: (_) {});
    await openEditor(tester, facade);
    final l10n = localizations(tester);
    try {
      await tester.tap(find.text(l10n.reset));
      await tester.pumpAndSettle();
      await facade.save(QuickActionSelection([QuickAction.support]));
      await tester.tap(find.text(l10n.undo));
      await tester.pumpAndSettle();
      expect(storage.value, '["support"]');
    } finally {
      await clearNotice(tester);
    }
  });

  testWidgets(
    'unavailable Buy is hidden without a write and survives a visible edit',
    (tester) async {
      final storage = _EditorStorage()..value = '["buy","map","transfer"]';
      await openEditor(
        tester,
        QuickActionsFacade(storage: storage, warning: (_) {}),
        available: defaults.toSet(),
      );
      final l10n = localizations(tester);
      expect(find.text(l10n.buy), findsNothing);
      expect(storage.writes, 0);
      expect(storage.value, '["buy","map","transfer"]');
      await tester.tap(find.byTooltip(l10n.removeAction(l10n.map)));
      await tester.pumpAndSettle();
      expect(storage.value, '["buy","transfer"]');
      expect(find.text(l10n.transfer), findsNWidgets(2));
    },
  );

  testWidgets(
    'legacy fourth selection stays in More after removing one Home action',
    (tester) async {
      final storage = _EditorStorage()
        ..value = '["map","transfer","history","settings"]';
      await openEditor(
        tester,
        QuickActionsFacade(storage: storage, warning: (_) {}),
      );
      final l10n = localizations(tester);
      expect(storage.value, '["map","transfer","history","settings"]');
      await tester.tap(find.byTooltip(l10n.removeAction(l10n.map)));
      await tester.pumpAndSettle();
      expect(storage.value, '["transfer","history"]');
      expect(find.byTooltip(l10n.addAction(l10n.settings)), findsOneWidget);
    },
  );
}

void stressEditorTests() {
  for (final locale in ['en', 'fr']) {
    for (final count in [0, 1, 4, 10]) {
      for (final dark in [false, true]) {
        testWidgets(
          'editor $locale $count legacy choices dark=$dark at 200 percent',
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
              locale: Locale(locale),
              textScale: 2,
              dark: dark,
            );
            final l10n = localizations(tester);
            expect(
              tester.getRect(find.text(l10n.reset)).bottom,
              lessThanOrEqualTo(800),
            );
            expect(tester.getRect(find.text(l10n.reset)).top, greaterThan(0));
            expect(find.text(l10n.onHome), findsOneWidget);
            expect(find.text(l10n.inMore), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}

class _EditorStorage extends MemoryStorage {
  int writes = 0;
  int inFlight = 0;
  int maximumInFlight = 0;
  bool failRemove = false;
  Completer<void>? gate;

  @override
  Future<void> write(String key, String value) async {
    writes++;
    inFlight++;
    if (inFlight > maximumInFlight) maximumInFlight = inFlight;
    try {
      await gate?.future;
      await super.write(key, value);
    } finally {
      inFlight--;
    }
  }

  @override
  Future<void> remove(String key) async {
    if (failRemove) throw Exception('remove failed');
    await super.remove(key);
  }
}
