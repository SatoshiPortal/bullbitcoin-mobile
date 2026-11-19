import 'package:ark/ark.dart';
import 'package:bull_ark/generated/l10n/ark_localizations.dart';
import 'package:bull_ark/src/ui/ark_information_screen.dart';
import 'package:bull_ark/src/ui/ark_vtxos_screen.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart'
    show
        Builder,
        ThemeData,
        InkWell,
        RichText,
        MaterialLocalizations,
        MediaQuery,
        TextScaler,
        Offset,
        Size,
        MaterialApp,
        GlobalMaterialLocalizations;
import 'package:primitives/primitives.dart';

import '../ark_information_widget_test.dart' show config, details;
import '../ark_vtxos_screen_test.dart' show view, coin;

Widget scaled(Widget child, double scale) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child,
  ),
);

void register(Map<String, ThemeData> themes) {
  setUpAll(() async {
    for (final font in {
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      'Golos Text': 'assets/fonts/GolosText.ttf',
      'Bebas Neue': 'assets/fonts/BebasNeue-Regular.ttf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });
  for (final theme in themes.entries) {
    group(theme.key, () {
      Widget app(Widget child, {String language = 'en'}) => MaterialApp(
        locale: Locale(language),
        theme: theme.value,
        supportedLocales: ArkLocalizations.supportedLocales,
        localizationsDelegates: const [
          ArkLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: BullAmountScope(
          snapshot: const BullAmountSnapshot(
            unit: BitcoinUnit.sats,
            hideAmounts: false,
            isReady: true,
          ),
          writeUnit: (_) async => false,
          child: child,
        ),
      );
      void viewport(WidgetTester tester) {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      }

      testWidgets('nominal inventory rows are contiguous 64 dp actions', (
        tester,
      ) async {
        viewport(tester);
        await tester.pumpWidget(
          app(
            ArkVtxosScreen(
              snapshot: view(values: [coin('first'), coin('second')]),
              onRenew: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final first = tester.getRect(
          find.byKey(const ValueKey('vtxo-details-first')),
        );
        final second = tester.getRect(
          find.byKey(const ValueKey('vtxo-details-second')),
        );
        expect(first.height, closeTo(64, 0.1));
        expect(second.top, closeTo(first.bottom, 0.1));
        await tester.tap(find.byKey(const ValueKey('vtxo-details-first')));
        await tester.pumpAndSettle();
        expect(find.text('VTXO details'), findsOneWidget);
      });

      testWidgets(
        'proven empty centers below filters and uses a compact Board target',
        (tester) async {
          viewport(tester);
          var boards = 0;
          await tester.pumpWidget(
            app(
              ArkVtxosScreen(
                snapshot: view(values: []),
                onRenew: (_) {},
                onBoard: () => boards++,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final group = find.byWidgetPredicate(
            (widget) =>
                widget is Column &&
                widget.children.whereType<BullText>().any(
                  (text) => text.text == 'No VTXOs yet',
                ),
          );
          final rect = tester.getRect(group);
          final bottomOfFilters =
              tester.getBottomLeft(find.text('All 0')).dy + BullSpacing.md;
          expect(
            rect.center.dy,
            closeTo((bottomOfFilters + 844 - BullSpacing.md) / 2, 28),
          );
          final target = find.widgetWithText(BullButton, 'Board to Ark');
          final action = tester.getRect(target);
          expect(action.width, lessThan(240));
          expect(action.height, greaterThanOrEqualTo(48));
          await tester.tapAt(action.topLeft + const Offset(2, 2));
          expect(boards, 1);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'large text empty stays scrollable with a reachable Board action',
        (tester) async {
          viewport(tester);
          var boards = 0;
          await tester.pumpWidget(
            app(
              scaled(
                ArkVtxosScreen(
                  snapshot: view(values: []),
                  onRenew: (_) {},
                  onBoard: () => boards++,
                ),
                1.8,
              ),
              language: 'fr',
            ),
          );
          await tester.pumpAndSettle();
          final target = find.byWidgetPredicate(
            (widget) => widget is BullButton,
          );
          await tester.ensureVisible(target);
          await tester.tap(target);
          expect(boards, 1);
          expect(tester.takeException(), isNull);
        },
      );

      for (final language in ['en', 'fr']) {
        testWidgets(
          'absolute and remaining block integers use $language locale',
          (tester) async {
            viewport(tester);
            await tester.pumpWidget(
              app(
                ArkVtxosScreen(
                  snapshot: view(
                    tip: 972552,
                    values: [coin('height', expiry: 974568)],
                  ),
                  renewalThresholdBlocks: 4032,
                  onRenew: (_) {},
                ),
                language: language,
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('vtxo-details-height')));
            await tester.pumpAndSettle();
            expect(
              find.text(language == 'en' ? 'Block 974,568' : 'Bloc 974 568'),
              findsOneWidget,
            );
            expect(
              details(tester),
              containsPair(
                language == 'en' ? 'Blocks left' : 'Blocs restants',
                language == 'en' ? '2,016' : '2 016',
              ),
            );
            expect(find.textContaining('974568 blocks'), findsNothing);
            expect(
              find.textContaining(
                language == 'en' ? 'Auto-renew is configured 4,032 blocks' : 'Le renouvellement automatique est configuré 4\u202f032 blocs',
              ),
              findsOneWidget,
            );
          },
        );
      }

      for (final tip in <int?>[0, null]) {
        testWidgets(
          'zero height remains known while missing tip stays unknown tip=$tip',
          (tester) async {
            viewport(tester);
            await tester.pumpWidget(
              app(
                ArkVtxosScreen(
                  snapshot: view(tip: tip, values: [coin('zero', expiry: 0)]),
                  onRenew: (_) {},
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('vtxo-details-zero')));
            await tester.pumpAndSettle();
            expect(find.text('Block 0'), findsOneWidget);
            expect(
              details(tester),
              containsPair('Blocks left', tip == null ? 'Unavailable' : '0'),
            );
          },
        );
      }

      testWidgets(
        'Info compact columns keep ordinary boarding labels on one line',
        (tester) async {
          viewport(tester);
          final snapshot = ArkSnapshot(
            account: config().id,
            revision: 1,
            observedAt: DateTime.utc(2026),
            stale: false,
            serverInfo: ArkServerInfo(
              publicKey: 'public-server-key',
              serverUri: config().arkUrl,
              minimumBoard: Sats.fromInt(50000),
              maximumVtxo: Sats.fromInt(10000000),
              boardConfirmations: 0,
              vtxoLifetimeBlocks: 4032,
              roundIntervalSeconds: 3600,
            ),
          );
          await tester.pumpWidget(
            app(ArkInformationScreen(snapshot: snapshot, config: config())),
          );
          await tester.pumpAndSettle();
          expect(
            tester.getSize(find.text('Minimum board amount')).height,
            lessThan(30),
          );
          expect(
            details(tester),
            containsPair('VTXO lifetime', '4,032 blocks'),
          );
          expect(details(tester), containsPair('Round interval', '3,600 sec'));
          expect(details(tester), containsPair('Required confirmations', '0'));
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'nominal unknown server keeps its dot and whole status together',
        (tester) async {
          viewport(tester);
          await tester.pumpWidget(
            app(
              ArkInformationScreen(
                snapshot: view(values: []),
                config: config(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final server = find.byWidgetPredicate(
            (widget) =>
                widget is BullDetailsTableItem &&
                widget.label == config().arkUrl.host,
          );
          final row = tester.widget<BullDetailsTableItem>(server);
          final status = row.displayWidget;
          if (status is! Wrap) throw StateError('Missing server status group');
          final dot = status.children.whereType<Container>().single;
          final label = status.children.whereType<BullText>().single;
          expect(label.text, 'Unavailable');
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.byWidget(label),
              matching: find.byType(RichText),
            ),
          );
          expect(paragraph.text.toPlainText(), 'Unavailable');
          expect(
            paragraph.getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 11),
            ),
            hasLength(1),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          final dotRect = tester.getRect(find.byWidget(dot));
          final labelRect = tester.getRect(find.byWidget(label));
          expect(dotRect.center.dy, closeTo(labelRect.center.dy, 0.1));
          final copy = tester.getRect(
            find.descendant(of: server, matching: find.byType(InkWell)),
          );
          expect(copy.width, greaterThanOrEqualTo(48));
          expect(copy.height, greaterThanOrEqualTo(48));
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'French enlarged server status has a named edge-tappable 48 dp Copy',
        (tester) async {
          viewport(tester);
          final semantics = tester.ensureSemantics();
          try {
            final writes = <String>[];
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              SystemChannels.platform,
              (call) async {
                if (call.method == 'Clipboard.setData') {
                  final args = call.arguments;
                  if (args is Map && args['text'] is String) {
                    writes.add(args['text'] as String);
                  }
                }
                return null;
              },
            );
            addTearDown(
              () => tester.binding.defaultBinaryMessenger
                  .setMockMethodCallHandler(SystemChannels.platform, null),
            );
            await tester.pumpWidget(
              app(
                scaled(
                  ArkInformationScreen(
                    snapshot: ArkSnapshot(
                      account: config().id,
                      revision: 1,
                      observedAt: DateTime.utc(2026),
                      stale: false,
                      serverInfo: ArkServerInfo(
                        publicKey: 'abcdefghij-public-synthetic-qrstuvwx',
                        serverUri: config().arkUrl,
                      ),
                    ),
                    config: config(),
                    serverConnection: (config().id, config().arkUrl, false),
                  ),
                  1.8,
                ),
                language: 'fr',
              ),
            );
            await tester.pumpAndSettle();
            final row = find.byWidgetPredicate(
              (widget) =>
                  widget is BullDetailsTableItem &&
                  widget.label == config().arkUrl.host,
            );
            final context = tester.element(row);
            final copyName = MaterialLocalizations.of(context).copyButtonLabel;
            expect(copyName.toLowerCase(), contains('copier'));
            final control = find.descendant(
              of: row,
              matching: find.bySemanticsLabel(RegExp(copyName)),
            );
            expect(control, findsOneWidget);
            await tester.ensureVisible(control);
            final target = tester.getRect(control);
            expect(target.width, greaterThanOrEqualTo(48));
            expect(target.height, greaterThanOrEqualTo(48));
            await tester.tapAt(target.bottomRight - const Offset(1, 1));
            await tester.pump();
            expect(writes, [config().arkUrl.toString()]);
            final shortKey = find.text('abcdefghij…qrstuvwx');
            expect(shortKey, findsOneWidget);
            await tester.ensureVisible(shortKey);
            expect(tester.getBottomLeft(shortKey).dy, lessThanOrEqualTo(844));
            final keyRow = find.byWidgetPredicate(
              (widget) =>
                  widget is BullDetailsTableItem &&
                  widget.copyValue == 'abcdefghij-public-synthetic-qrstuvwx',
            );
            final keyCopy = find.descendant(
              of: keyRow,
              matching: find.bySemanticsLabel(RegExp(copyName)),
            );
            await tester.ensureVisible(keyCopy);
            final keyTarget = tester.getRect(keyCopy);
            expect(keyTarget.width, greaterThanOrEqualTo(48));
            expect(keyTarget.height, greaterThanOrEqualTo(48));
            await tester.tapAt(keyTarget.topLeft + const Offset(1, 1));
            await tester.pump();
            expect(writes, [
              config().arkUrl.toString(),
              'abcdefghij-public-synthetic-qrstuvwx',
            ]);
            expect(find.text('Hors ligne'), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.pump(const Duration(seconds: 4));
            await tester.pumpAndSettle();
          } finally {
            semantics.dispose();
          }
        },
      );
    });
  }
}
