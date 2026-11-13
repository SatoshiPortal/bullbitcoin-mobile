import 'dart:async';
import 'dart:convert';

import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullQuickAction, BullShapes, BullSnackBar;
import 'package:bull_ui/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
  QuickActionsCubit facade, {
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
                builder: (_) => QuickActionsCustomizationScreen(cubit: facade),
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

String? homeValue(String? raw) {
  if (raw == null) return null;
  final value = jsonDecode(raw);
  return jsonEncode((value as Map)['home']);
}

Future<void> semanticMove(
  WidgetTester tester,
  QuickAction action,
  String label,
) async {
  final handle = tester.ensureSemantics();
  try {
    final row = find.byKey(ValueKey(action.id));
    if (row.evaluate().isEmpty) {
      await tester.scrollUntilVisible(row, 100);
      await tester.pumpAndSettle();
    }
    final viewport = tester.getRect(find.byType(ReorderableListView));
    final bounds = tester.getRect(row);
    if (bounds.top < viewport.top || bounds.bottom > viewport.bottom) {
      await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
      await tester.pumpAndSettle();
    }
    final node = tester.getSemantics(
      find.descendant(of: row, matching: find.byType(Semantics)).first,
    );
    final ids = node.getSemanticsData().customSemanticsActionIds ?? [];
    expect(
      ids.map((id) => CustomSemanticsAction.getAction(id)?.label),
      contains(label),
      reason: 'Accessible action for ${action.id}, node ${node.label}',
    );
    final id = ids.singleWhere(
      (id) => CustomSemanticsAction.getAction(id)?.label == label,
    );
    final owner = node.owner;
    expect(owner, isNotNull);
    owner?.performAction(node.id, SemanticsAction.customAction, id);
    await tester.pumpAndSettle();
  } finally {
    handle.dispose();
  }
}

void main() {
  stressEditorTests();
  testWidgets('long press on the label reorders and saves at drop', (
    tester,
  ) async {
    final storage = _EditorStorage();
    await openEditor(
      tester,
      QuickActionsCubit(
        storage: storage,
        warning: (_) {},
        exchangeVisible: Stream.value(true),
      ),
    );
    final from = tester.getRect(find.byKey(const ValueKey('transfer')));
    final to = tester.getRect(find.byKey(const ValueKey('map')));
    final gesture = await tester.startGesture(
      Offset(from.left + 80, from.center.dy),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byWidgetPredicate((w) => w is Material && w.elevation > 0),
      findsWidgets,
    );
    expect(storage.writes, 0);
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump(const Duration(milliseconds: 30));
    await gesture.moveTo(to.center);
    await tester.pump(const Duration(milliseconds: 350));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(homeValue(storage.value), '["transfer","map","history"]');
    expect(storage.writes, 1);
    expect(find.byType(QuickActionsCustomizationScreen), findsOneWidget);
  });

  for (final locale in ['en', 'fr']) {
    testWidgets('two sections and a secondary fixed reset in $locale', (
      tester,
    ) async {
      final storage = MemoryStorage();
      await openEditor(
        tester,
        QuickActionsCubit(
          storage: storage,
          warning: (_) {},
          exchangeVisible: Stream.value(true),
        ),
        locale: Locale(locale),
      );
      final l10n = localizations(tester);
      expect(find.text(l10n.onHome), findsOneWidget);
      expect(find.text(l10n.dragHint), findsOneWidget);
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
      await tester.scrollUntilVisible(find.text(l10n.inMore), 120);
      expect(find.text(l10n.inMore), findsOneWidget);
    });
  }

  testWidgets('moving a fourth action Home displaces the old third into More', (
    tester,
  ) async {
    final storage = _EditorStorage();
    await openEditor(
      tester,
      QuickActionsCubit(
        storage: storage,
        warning: (_) {},
        exchangeVisible: Stream.value(true),
      ),
    );
    final l10n = localizations(tester);
    await semanticMove(tester, QuickAction.buy, l10n.moveToHome);
    expect(homeValue(storage.value), '["map","transfer","buy"]');
    final value = jsonDecode(storage.value ?? '{}') as Map;
    expect((value['more'] as List).first, 'history');
    expect(storage.writes, 1);
    expect(
      find.descendant(
        of: find.byType(ReorderableListView),
        matching: find.byType(IconButton),
      ),
      findsNothing,
    );
  });

  testWidgets('moving between sections saves each operation immediately', (
    tester,
  ) async {
    final storage = _EditorStorage()
      ..value = '{"home":["map","transfer"],"more":[]}';
    await openEditor(
      tester,
      QuickActionsCubit(
        storage: storage,
        warning: (_) {},
        exchangeVisible: Stream.value(true),
      ),
    );
    final l10n = localizations(tester);
    await semanticMove(tester, QuickAction.buy, l10n.moveToHome);
    expect(homeValue(storage.value), '["map","transfer","buy"]');
    await semanticMove(tester, QuickAction.buy, l10n.moveToMore);
    expect(homeValue(storage.value), '["map","transfer"]');
    expect(storage.writes, 2);
  });

  testWidgets('failed write rolls back and shows saveFailed in a SnackBar', (
    tester,
  ) async {
    final storage = _EditorStorage()
      ..value = '{"home":["map","transfer"],"more":[]}'
      ..failWrite = true;
    await openEditor(
      tester,
      QuickActionsCubit(
        storage: storage,
        warning: (_) {},
        exchangeVisible: Stream.value(true),
      ),
    );
    final l10n = localizations(tester);
    try {
      await semanticMove(tester, QuickAction.map, l10n.moveToMore);
      await tester.pumpAndSettle();
      expect(homeValue(storage.value), '["map","transfer"]');
      expect(find.text(l10n.map), findsNWidgets(2));
      expect(find.text(l10n.saveFailed), findsOneWidget);
      storage.failWrite = false;
      await semanticMove(tester, QuickAction.map, l10n.moveToMore);
      await tester.pumpAndSettle();
      expect(homeValue(storage.value), '["transfer"]');
    } finally {
      await clearNotice(tester);
    }
  });

  testWidgets(
    'Restore defaults persists immediately and Undo restores the complete previous list',
    (tester) async {
      final original = '{"home":["buy","map","transfer","history"],"more":[]}';
      final storage = _EditorStorage()..value = original;
      final facade = QuickActionsCubit(
        storage: storage,
        warning: (_) {},
        exchangeVisible: Stream.value(false),
      );
      await openEditor(tester, facade);
      final l10n = localizations(tester);
      try {
        await tester.tap(find.text(l10n.reset));
        await tester.pumpAndSettle();
        expect(storage.value, isNull);
        expect(facade.state.selection, isNull);
        expect(find.byType(QuickActionsCustomizationScreen), findsOneWidget);
        expect(find.text(l10n.defaultsRestored), findsOneWidget);
        await tester.tap(find.text(l10n.undo));
        await tester.pumpAndSettle();
        expect(storage.value, original);
        expect(facade.state.selection?.actions.first, QuickAction.buy);
      } finally {
        await clearNotice(tester);
      }
    },
  );

  for (final previous in <String?>[null, '{"home":[],"more":[]}']) {
    testWidgets(
      'Undo preserves automatic versus explicitly empty preference $previous',
      (tester) async {
        final storage = _EditorStorage()..value = previous;
        await openEditor(
          tester,
          QuickActionsCubit(
            storage: storage,
            warning: (_) {},
            exchangeVisible: Stream.value(true),
          ),
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
      ..value = '{"home":["buy"],"more":[]}'
      ..failRemove = true;
    await openEditor(
      tester,
      QuickActionsCubit(
        storage: storage,
        warning: (_) {},
        exchangeVisible: Stream.value(true),
      ),
    );
    final l10n = localizations(tester);
    try {
      await tester.tap(find.text(l10n.reset));
      await tester.pumpAndSettle();
      expect(homeValue(storage.value), '["buy"]');
      expect(find.text(l10n.saveFailed), findsOneWidget);
      expect(find.text(l10n.undo), findsNothing);
    } finally {
      await clearNotice(tester);
    }
  });

  testWidgets('failed Undo stays at defaults and reports the write error', (
    tester,
  ) async {
    final storage = _EditorStorage()..value = '{"home":["buy"],"more":[]}';
    await openEditor(
      tester,
      QuickActionsCubit(
        storage: storage,
        warning: (_) {},
        exchangeVisible: Stream.value(true),
      ),
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
        ..value = '{"home":["map","transfer"],"more":[]}'
        ..gate = gate;
      await openEditor(
        tester,
        QuickActionsCubit(
          storage: storage,
          warning: (_) {},
          exchangeVisible: Stream.value(true),
        ),
      );
      final l10n = localizations(tester);
      await semanticMove(tester, QuickAction.map, l10n.moveToMore);
      await tester.pump();
      expect(storage.writes, 1);
      expect(homeValue(storage.value), '["map","transfer"]');
      expect(
        tester
            .widgetList<ReorderableDelayedDragStartListener>(
              find.byType(ReorderableDelayedDragStartListener),
            )
            .every((row) => !row.enabled),
        isTrue,
      );
      expect(
        tester.widget<BullButton>(find.byType(BullButton)).disabled,
        isTrue,
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(homeValue(storage.value), '["transfer"]');
      expect(storage.maximumInFlight, 1);
    },
  );

  testWidgets('pending save survives closing the editor', (tester) async {
    final gate = Completer<void>();
    final storage = _EditorStorage()
      ..value = '{"home":["map","transfer"],"more":[]}'
      ..gate = gate;
    final facade = QuickActionsCubit(
      storage: storage,
      warning: (_) {},
      exchangeVisible: Stream.value(true),
    );
    await openEditor(tester, facade);
    final l10n = localizations(tester);
    await semanticMove(tester, QuickAction.map, l10n.moveToMore);
    await tester.pump();
    Navigator.of(
      tester.element(find.byType(QuickActionsCustomizationScreen)),
    ).pop();
    await tester.pumpAndSettle();
    gate.complete();
    await tester.pumpAndSettle();
    expect(homeValue(storage.value), '["transfer"]');
    expect(facade.state.selection?.actions, [QuickAction.transfer]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed pending save reports on the root overlay after closing', (
    tester,
  ) async {
    final gate = Completer<void>();
    final storage = _EditorStorage()
      ..value = '{"home":["map","transfer"],"more":[]}'
      ..gate = gate
      ..failWrite = true;
    await openEditor(
      tester,
      QuickActionsCubit(
        storage: storage,
        warning: (_) {},
        exchangeVisible: Stream.value(true),
      ),
    );
    final l10n = localizations(tester);
    try {
      await semanticMove(tester, QuickAction.map, l10n.moveToMore);
      await tester.pump();
      Navigator.of(
        tester.element(find.byType(QuickActionsCustomizationScreen)),
      ).pop();
      await tester.pumpAndSettle();
      gate.complete();
      await tester.pumpAndSettle();
      expect(homeValue(storage.value), '["map","transfer"]');
      expect(find.text(l10n.saveFailed), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await clearNotice(tester);
    }
  });

  testWidgets('Undo remains functional after closing the editor', (
    tester,
  ) async {
    final storage = _EditorStorage()..value = '{"home":["buy"],"more":[]}';
    await openEditor(
      tester,
      QuickActionsCubit(
        storage: storage,
        warning: (_) {},
        exchangeVisible: Stream.value(true),
      ),
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
      expect(homeValue(storage.value), '["buy"]');
      expect(tester.takeException(), isNull);
    } finally {
      await clearNotice(tester);
    }
  });

  testWidgets('Undo cannot overwrite a newer confirmed preference', (
    tester,
  ) async {
    final storage = _EditorStorage()..value = '{"home":["buy"],"more":[]}';
    final facade = QuickActionsCubit(
      storage: storage,
      warning: (_) {},
      exchangeVisible: Stream.value(true),
    );
    await openEditor(tester, facade);
    final l10n = localizations(tester);
    try {
      await tester.tap(find.text(l10n.reset));
      await tester.pumpAndSettle();
      await facade.save(QuickActionSelection([QuickAction.support]));
      await tester.tap(find.text(l10n.undo));
      await tester.pumpAndSettle();
      expect(homeValue(storage.value), '["support"]');
    } finally {
      await clearNotice(tester);
    }
  });

  testWidgets(
    'unavailable Buy is hidden without a write and survives a visible edit',
    (tester) async {
      final storage = _EditorStorage()
        ..value = '{"home":["buy","map","transfer"],"more":[]}';
      await openEditor(
        tester,
        QuickActionsCubit(
          storage: storage,
          warning: (_) {},
          exchangeVisible: Stream.value(false),
        ),
      );
      final l10n = localizations(tester);
      expect(find.text(l10n.buy), findsNothing);
      expect(storage.writes, 0);
      expect(homeValue(storage.value), '["buy","map","transfer"]');
      await semanticMove(tester, QuickAction.map, l10n.moveToMore);
      await tester.pumpAndSettle();
      expect(homeValue(storage.value), '["buy","transfer"]');
      expect(find.text(l10n.transfer), findsNWidgets(2));
    },
  );

  testWidgets('fourth selection stays in More after removing one Home action', (
    tester,
  ) async {
    final storage = _EditorStorage()
      ..value = '{"home":["map","transfer","history","settings"],"more":[]}';
    await openEditor(
      tester,
      QuickActionsCubit(
        storage: storage,
        warning: (_) {},
        exchangeVisible: Stream.value(true),
      ),
    );
    final l10n = localizations(tester);
    expect(homeValue(storage.value), '["map","transfer","history","settings"]');
    await semanticMove(tester, QuickAction.map, l10n.moveToMore);
    await tester.pumpAndSettle();
    expect(homeValue(storage.value), '["transfer","history"]');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings')),
      120,
    );
    expect(find.byKey(const ValueKey('settings')), findsOneWidget);
  });
}

void stressEditorTests() {
  for (final locale in ['en', 'fr']) {
    for (final count in [0, 1, 4, 10]) {
      for (final dark in [false, true]) {
        testWidgets('editor $locale $count choices dark=$dark at 200 percent', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final storage = MemoryStorage()
            ..value =
                '[${QuickAction.values.take(count).map((a) => '"${a.id}"').join(',')}]';
          await openEditor(
            tester,
            QuickActionsCubit(
              storage: storage,
              warning: (_) {},
              exchangeVisible: Stream.value(true),
            ),
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
          await tester.scrollUntilVisible(find.text(l10n.inMore), 120);
          expect(find.text(l10n.inMore), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
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
