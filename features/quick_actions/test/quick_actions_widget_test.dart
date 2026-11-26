import 'customization_test.dart'
    show openEditor, localizations, semanticMove, homeValue;

import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_ui/testing.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullQuickAction,
        BullText,
        BullTypographyX,
        BullAmountScope,
        BullAmountSnapshot,
        BullIcons;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

import 'quick_actions_test.dart' show MemoryStorage;

void main() {
  for (final pinned in [false, true]) {
    testWidgets(
      'unread support messages show on ${pinned ? 'Support' : 'More'}',
      (tester) async {
        final cubit = createQuickActionsCubit(
          storage: MemoryStorage(),
          warning: (_) {},
          exchangeVisible: Stream.value(false),
        );
        addTearDown(cubit.close);
        if (pinned) {
          await cubit.save(QuickActionSelection([QuickAction.support]));
        }
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: testBullExtensions),
            localizationsDelegates: const [QuickActionsLocalizations.delegate],
            home: Scaffold(
              body: QuickActionsRow(
                cubit: cubit,
                onAction: (_) {},
                onCustomize: () {},
                unreadSupportMessages: 3,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        int badge(String label) => tester
            .widget<BullQuickAction>(
              find.byWidgetPredicate(
                (widget) => widget is BullQuickAction && widget.label == label,
              ),
            )
            .badgeCount;

        expect(badge('More'), pinned ? 0 : 3);
        if (pinned) {
          expect(badge('Support'), 3);
          expect(find.text('3'), findsOneWidget);
        } else {
          await tester.tap(find.text('More'));
          await tester.pumpAndSettle();
          expect(badge('Support'), 3);
        }
      },
    );
  }

  for (final pinned in [false, true]) {
    testWidgets('amount visibility toggles in ${pinned ? 'Home' : 'More'}', (
      tester,
    ) async {
      final cubit = createQuickActionsCubit(
        storage: MemoryStorage(),
        warning: (_) {},
        exchangeVisible: Stream.value(false),
      );
      addTearDown(cubit.close);
      if (pinned) {
        await cubit.save(QuickActionSelection([QuickAction.toggleAmounts]));
      }
      var hidden = false;
      var calls = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => BullAmountScope(
            snapshot: BullAmountSnapshot(
              unit: BitcoinUnit.btc,
              hideAmounts: hidden,
              isReady: true,
            ),
            writeUnit: (_) async => true,
            child: MaterialApp(
              theme: ThemeData(extensions: testBullExtensions),
              localizationsDelegates: const [
                QuickActionsLocalizations.delegate,
              ],
              home: Scaffold(
                body: QuickActionsRow(
                  cubit: cubit,
                  onAction: (action) {
                    expect(action, QuickAction.toggleAmounts);
                    calls++;
                    setState(() => hidden = !hidden);
                  },
                  onCustomize: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in ['Hide', 'Show']) {
        if (!pinned) {
          await tester.tap(find.text('More'));
          await tester.pumpAndSettle();
        }
        final control = find.byWidgetPredicate(
          (widget) => widget is BullQuickAction && widget.label == label,
        );
        expect(
          tester.widget<BullQuickAction>(control).semanticLabel,
          '$label amounts',
        );
        expect(
          tester.widget<BullQuickAction>(control).icon,
          BullIcons.currencyBitcoin,
        );
        await tester.tap(control);
        await tester.pumpAndSettle();
      }
      expect(calls, 2);
      expect(hidden, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('More shows the complement and dispatches the chosen action', (
    tester,
  ) async {
    final facade = createQuickActionsCubit(
      storage: MemoryStorage(),
      warning: (_) {},
      exchangeVisible: Stream.value(true),
    );
    QuickAction? chosen;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: const [QuickActionsLocalizations.delegate],
        home: Scaffold(
          body: QuickActionsRow(
            cubit: facade,
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
    final title = find
        .byWidgetPredicate(
          (widget) => widget is BullText && widget.text == 'More',
        )
        .last;
    final edit = find.byWidgetPredicate(
      (widget) => widget is BullText && widget.text == 'Edit',
    );
    expect(
      tester.widget<BullText>(title).style,
      tester.element(title).bullType.title,
    );
    expect(
      tester.widget<BullText>(edit).style,
      tester.element(edit).bullType.label,
    );
    expect(find.text('Exchange'), findsOneWidget);
    await tester.tap(find.text('Pay'));
    await tester.pumpAndSettle();
    expect(chosen, QuickAction.pay);
  });

  testWidgets('More remains available when exchange is hidden', (tester) async {
    final facade = createQuickActionsCubit(
      storage: MemoryStorage(),
      warning: (_) {},
      exchangeVisible: Stream.value(false),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: const [QuickActionsLocalizations.delegate],
        home: Scaffold(
          body: QuickActionsRow(
            cubit: facade,
            onAction: (_) {},
            onCustomize: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('More'), findsOneWidget);
  });

  testWidgets('customization autosaves without closing the editor', (
    tester,
  ) async {
    final storage = MemoryStorage();
    final facade = createQuickActionsCubit(
      storage: storage,
      warning: (_) {},
      exchangeVisible: Stream.value(true),
    );
    await openEditor(tester, facade);
    final l10n = localizations(tester);
    await semanticMove(tester, QuickAction.settings, l10n.moveToMore);
    await tester.pumpAndSettle();
    expect(homeValue(storage.value), '["history","transfer"]');
    expect(find.byType(QuickActionsCustomizationScreen), findsOneWidget);
  });
  testWidgets('four cells stay on one line at 360 pixels with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final facade = createQuickActionsCubit(
      storage: MemoryStorage(),
      warning: (_) {},
      exchangeVisible: Stream.value(true),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: const [QuickActionsLocalizations.delegate],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: Scaffold(
          body: QuickActionsRow(
            cubit: facade,
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
      final facade = createQuickActionsCubit(
        storage: MemoryStorage(),
        warning: (_) {},
        exchangeVisible: Stream.value(true),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: testBullExtensions),
          locale: locale,
          supportedLocales: const [Locale('es'), Locale('fr')],
          localizationsDelegates: const [
            QuickActionsFallbackDelegate(),
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(
            body: QuickActionsRow(
              cubit: facade,
              onAction: (_) {},
              onCustomize: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(locale.languageCode == 'fr' ? 'Réglages' : 'Settings'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
