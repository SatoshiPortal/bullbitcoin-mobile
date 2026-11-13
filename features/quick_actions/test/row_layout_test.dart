import 'dart:async';

import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_ui/bull_ui.dart' show BullQuickAction;
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
const available = {...defaults, QuickAction.support, QuickAction.priceHistory};

class DelayedStorage extends MemoryStorage {
  final ready = Completer<String?>();
  @override
  Future<String?> read(String key) => ready.future;
}

Future<void> mount(
  WidgetTester tester,
  QuickActionsCubit facade, {
  VoidCallback? onCustomize,
}) => tester.pumpWidget(
  MaterialApp(
    theme: ThemeData(extensions: testBullExtensions),
    localizationsDelegates: const [
      QuickActionsFallbackDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: QuickActionsRow(
          cubit: facade,
          onAction: (_) {},
          onCustomize: onCustomize ?? () {},
        ),
      ),
    ),
  ),
);

void main() {
  matrixTests();
  testWidgets('all cell widths match, including More, and long press edits', (
    tester,
  ) async {
    var edits = 0;
    final facade = createQuickActionsCubit(
      storage: MemoryStorage(),
      warning: (_) {},
      exchangeVisible: Stream.value(true),
    );
    await mount(tester, facade, onCustomize: () => edits++);
    await tester.pumpAndSettle();
    final buttons = find.byType(BullQuickAction);
    expect(buttons, findsNWidgets(4));
    final width = tester.getSize(buttons.first).width;
    for (var i = 1; i < 4; i++) {
      expect(tester.getSize(buttons.at(i)).width, closeTo(width, .01));
    }
    await tester.longPress(buttons.first);
    await tester.pumpAndSettle();
    expect(edits, 1);
    await tester.longPress(buttons.last);
    await tester.pumpAndSettle();
    expect(edits, 2);
  });

  testWidgets('loading reserves exactly the loaded row height', (tester) async {
    final storage = DelayedStorage();
    final facade = createQuickActionsCubit(
      storage: storage,
      warning: (_) {},
      exchangeVisible: Stream.value(true),
    );
    await mount(tester, facade);
    final before = tester.getSize(find.byType(QuickActionsRow));
    expect(before.height, BullQuickAction.height);
    expect(
      tester
          .widget<BullQuickAction>(find.byType(BullQuickAction).first)
          .disabled,
      isTrue,
    );
    storage.ready.complete(null);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(QuickActionsRow)), before);
    expect(
      tester
          .widget<BullQuickAction>(find.byType(BullQuickAction).first)
          .disabled,
      isFalse,
    );
  });

  testWidgets('More has title Edit and a compact grid, Edit closes the sheet', (
    tester,
  ) async {
    var edits = 0;
    final facade = createQuickActionsCubit(
      storage: MemoryStorage(),
      warning: (_) {},
      exchangeVisible: Stream.value(true),
    );
    await mount(tester, facade, onCustomize: () => edits++);
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Support'), findsOneWidget);
    expect(find.text('Price'), findsOneWidget);
    final settings = tester.getCenter(find.text('Settings'));
    final support = tester.getCenter(find.text('Support'));
    expect(settings.dy, closeTo(support.dy, .01));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(edits, 1);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('More'), findsOneWidget);
  });
}

// The full row keeps the wallet's real 13 dp margins at narrow widths.
void matrixTests() {
  for (final width in [320.0, 360.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final locale in [const Locale('en'), const Locale('fr')]) {
        testWidgets(
          'row $width dp ${locale.languageCode} ${scale}x keeps labels accessible',
          (tester) async {
            tester.view.physicalSize = Size(width, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final semantics = tester.ensureSemantics();
            try {
              final facade = createQuickActionsCubit(
                storage: MemoryStorage(),
                warning: (_) {},
                exchangeVisible: Stream.value(true),
              );
              await tester.pumpWidget(
                MaterialApp(
                  locale: locale,
                  supportedLocales: const [Locale('en'), Locale('fr')],
                  theme: ThemeData(extensions: testBullExtensions),
                  localizationsDelegates: const [
                    QuickActionsFallbackDelegate(),
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child ?? const SizedBox.shrink(),
                  ),
                  home: Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      child: QuickActionsRow(
                        cubit: facade,
                        onAction: (_) {},
                        onCustomize: () {},
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              final cells = find.byType(BullQuickAction);
              expect(cells, findsNWidgets(4));
              final first = tester.getRect(cells.first);
              for (var i = 0; i < 4; i++) {
                final rect = tester.getRect(cells.at(i));
                expect(rect.width, closeTo(first.width, .01));
                expect(rect.top, first.top);
                expect(rect.left, greaterThanOrEqualTo(13));
                expect(rect.right, lessThanOrEqualTo(width - 13));
                final cell = tester.widget<BullQuickAction>(cells.at(i));
                expect(
                  find.bySemanticsLabel(cell.semanticLabel ?? cell.label),
                  findsOneWidget,
                );
              }
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
  }
}
