import 'package:primitives/primitives.dart';
import 'dart:async';

import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_app.dart';

BullAmountSnapshot snapshot({
  BitcoinUnit unit = BitcoinUnit.sats,
  bool hide = false,
  bool ready = true,
}) => BullAmountSnapshot(unit: unit, hideAmounts: hide, isReady: ready);

Widget amount(String id, {bool negative = false}) => BullAmount(
  key: ValueKey(id),
  magnitude: Sats.fromInt(12345),
  isNegative: negative,
);

Widget host(
  Widget child, {
  ValueNotifier<BullAmountSnapshot>? preferences,
  Future<bool> Function(BitcoinUnit)? writer,
}) {
  final source = preferences ?? ValueNotifier(snapshot());
  return wrapWithTheme(
    ValueListenableBuilder<BullAmountSnapshot>(
      valueListenable: source,
      builder: (context, value, stableChild) => BullAmountScope(
        snapshot: value,
        writeUnit: (unit) async {
          final ok = await (writer?.call(unit) ?? Future.value(true));
          if (ok) {
            source.value = BullAmountSnapshot(
              unit: unit,
              hideAmounts: source.value.hideAmounts,
              isReady: source.value.isReady,
            );
          }
          return ok;
        },
        child: stableChild ?? const SizedBox(),
      ),
      child: child,
    ),
  );
}

class Probe extends StatelessWidget {
  const Probe(this.onBuild);
  final VoidCallback onBuild;
  @override
  Widget build(BuildContext context) {
    BullAmountScope.maybeOf(context);
    onBuild();
    return const SizedBox();
  }
}

void main() {
  tearDown(() => BullSnackBar.dismiss());

  testWidgets('tap remains local, has no icon and consumes parent navigation', (
    tester,
  ) async {
    var navigation = 0;
    final source = ValueNotifier(snapshot());
    await tester.pumpWidget(
      host(
        InkWell(
          onTap: () => navigation++,
          child: Column(
            children: [amount('a'), amount('b'), const Text('Details')],
          ),
        ),
        preferences: source,
      ),
    );
    expect(find.byType(Icon), findsNothing);
    await tester.tap(find.text('12,345 sats').first);
    await tester.pump();
    expect(find.text('0.00012345 BTC'), findsOneWidget);
    expect(find.text('12,345 sats'), findsOneWidget);
    expect(source.value.unit, BitcoinUnit.sats);
    expect(navigation, 0);
    await tester.tap(find.text('Details'));
    expect(navigation, 1);
    await tester.pumpWidget(const SizedBox());
    source.dispose();
  });

  testWidgets(
    'hide changes mask text and semantics without resetting a local override',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final source = ValueNotifier(snapshot());
      await tester.pumpWidget(host(amount('a'), preferences: source));
      await tester.tap(find.text('12,345 sats'));
      await tester.pump();
      source.value = snapshot(hide: true);
      await tester.pump();
      expect(find.text('** BTC'), findsOneWidget);
      final node = tester.getSemantics(find.byType(BullAmountUnitToggle));
      expect(node.value, '** BTC');
      expect(node.getSemanticsData().flagsCollection.isLiveRegion, isFalse);
      source.value = snapshot();
      await tester.pump();
      expect(find.text('0.00012345 BTC'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      source.dispose();
      semantics.dispose();
    },
  );

  testWidgets('unavailable settings mask values including privacy overrides', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        BullAmount(magnitude: Sats.fromInt(12345), overrideHideAmounts: true),
        preferences: ValueNotifier(snapshot(ready: false)),
      ),
    );
    expect(find.text('** sats'), findsOneWidget);
    expect(find.textContaining('12,345'), findsNothing);
  });

  testWidgets(
    'same-default global command and Undo clear every local override',
    (tester) async {
      final writes = <BitcoinUnit>[];
      await tester.pumpWidget(
        host(
          Column(children: [amount('a'), amount('b')]),
          writer: (unit) async {
            writes.add(unit);
            return true;
          },
        ),
      );
      await tester.tap(find.text('12,345 sats').first);
      await tester.pump();
      await tester.tap(find.text('12,345 sats'));
      await tester.pump();
      await tester.longPress(find.text('0.00012345 BTC').first);
      await tester.pumpAndSettle();
      expect(writes, [BitcoinUnit.sats]);
      expect(find.text('12,345 sats'), findsNWidgets(2));
      expect(find.text('Amounts displayed in sats everywhere'), findsOneWidget);
      await tester.tap(find.text('12,345 sats').first);
      await tester.pump();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(writes, [BitcoinUnit.sats, BitcoinUnit.sats]);
      expect(find.text('12,345 sats'), findsNWidgets(2));
    },
  );

  testWidgets(
    'feedback survives disposal of the initiating amount above the router',
    (tester) async {
      final pending = Completer<bool>();
      final visible = ValueNotifier(true);
      final source = ValueNotifier(snapshot());
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          theme: ThemeData(extensions: testBullExtensions),
          localizationsDelegates: bullUiLocalizationsDelegates,
          builder: (context, child) =>
              ValueListenableBuilder<BullAmountSnapshot>(
                valueListenable: source,
                builder: (context, value, stableChild) => BullAmountScope(
                  snapshot: value,
                  writeUnit: (unit) async {
                    final ok = await pending.future;
                    if (ok) source.value = snapshot(unit: unit);
                    return ok;
                  },
                  overlayResolver: () => navigatorKey.currentState?.overlay,
                  child: stableChild ?? const SizedBox(),
                ),
                child: child,
              ),
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (_, show, _) =>
                  show ? amount('a') : const Text('Remaining route'),
            ),
          ),
        ),
      );
      await tester.longPress(find.text('12,345 sats'));
      visible.value = false;
      await tester.pump();
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('Amounts displayed in BTC everywhere'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      // Undo uses the durable scope after the amount has disappeared as well.
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(source.value.unit, BitcoinUnit.sats);
      await tester.pumpWidget(const SizedBox());
      visible.dispose();
      source.dispose();
    },
  );

  testWidgets('equal snapshots do not notify dependent amounts', (
    tester,
  ) async {
    var builds = 0;
    final child = Probe(() => builds++);
    Widget tree() => wrapWithTheme(
      BullAmountScope(
        snapshot: snapshot(),
        writeUnit: (_) async => true,
        child: child,
      ),
    );
    await tester.pumpWidget(tree());
    final before = builds;
    await tester.pumpWidget(tree());
    expect(builds, before);
  });

  testWidgets('failed global writes never announce success or reset locals', (
    tester,
  ) async {
    await tester.pumpWidget(host(amount('a'), writer: (_) async => false));
    await tester.tap(find.text('12,345 sats'));
    await tester.pump();
    await tester.longPress(find.text('0.00012345 BTC'));
    await tester.pumpAndSettle();
    expect(find.text('0.00012345 BTC'), findsOneWidget);
    expect(
      find.text('Could not change the amount unit. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets(
    'long press has no competing tooltip and a named semantic action',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final writes = <BitcoinUnit>[];
      await tester.pumpWidget(
        host(
          amount('a'),
          writer: (unit) async {
            writes.add(unit);
            return true;
          },
        ),
      );
      expect(
        tester.widget<Tooltip>(find.byType(Tooltip)).triggerMode,
        TooltipTriggerMode.manual,
      );
      final node = tester.getSemantics(find.byType(BullAmountUnitToggle));
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(node.getSemanticsData().flagsCollection.isLiveRegion, isFalse);
      const action = CustomSemanticsAction(
        label: 'Change the default unit everywhere',
      );
      final id = CustomSemanticsAction.getIdentifier(action);
      expect(node.getSemanticsData().customSemanticsActionIds, contains(id));
      tester.binding.renderViews.first.owner?.semanticsOwner?.performAction(
        node.id,
        SemanticsAction.customAction,
        id,
      );
      await tester.pumpAndSettle();
      expect(writes, [BitcoinUnit.btc]);
      semantics.dispose();
    },
  );

  testWidgets('48 dp targets survive large text and keyboard activation', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: SizedBox(width: 180, child: amount('a')),
        ),
      ),
    );
    final size = tester.getSize(find.byType(TextButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('0.00012345 BTC'), findsOneWidget);
  });

  testWidgets('signed magnitudes and unsupported app locales remain safe', (
    tester,
  ) async {
    await tester.pumpWidget(host(amount('negative', negative: true)));
    expect(find.text('-12,345 sats'), findsOneWidget);
    expect(() => Sats(BigInt.from(-1)), throwsArgumentError);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: bullUiLocalizationsDelegates,
        theme: ThemeData(extensions: testBullExtensions),
        home: Scaffold(
          body: BullAmountScope(
            snapshot: snapshot(),
            writeUnit: (_) async => true,
            child: amount('a'),
          ),
        ),
      ),
    );
    expect(find.text('12,345 sats'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'global commands serialize and Undo restores the preceding committed default',
    (tester) async {
      final first = Completer<bool>();
      final writes = <BitcoinUnit>[];
      final source = ValueNotifier(snapshot());
      await tester.pumpWidget(
        host(
          Column(children: [amount('a'), amount('b')]),
          preferences: source,
          writer: (unit) async {
            writes.add(unit);
            return writes.length == 1 ? first.future : true;
          },
        ),
      );
      await tester.longPress(find.text('12,345 sats').first);
      await tester.tap(find.text('12,345 sats').last);
      await tester.pump();
      await tester.longPress(find.text('0.00012345 BTC'));
      await tester.pump();
      expect(writes, [BitcoinUnit.btc]);
      first.complete(true);
      await tester.pumpAndSettle();
      expect(writes, [BitcoinUnit.btc, BitcoinUnit.sats]);
      expect(source.value.unit, BitcoinUnit.sats);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(writes, [BitcoinUnit.btc, BitcoinUnit.sats, BitcoinUnit.btc]);
      expect(source.value.unit, BitcoinUnit.btc);
      await tester.pumpWidget(const SizedBox());
      source.dispose();
    },
  );

  testWidgets('an earlier Undo cannot write or dismiss newer feedback', (
    tester,
  ) async {
    final writes = <BitcoinUnit>[];
    await tester.pumpWidget(
      host(
        amount('a'),
        writer: (unit) async {
          writes.add(unit);
          return true;
        },
      ),
    );
    await tester.longPress(find.text('12,345 sats'));
    await tester.pumpAndSettle();
    final action = tester
        .widget<GestureDetector>(
          find
              .ancestor(
                of: find.text('Undo'),
                matching: find.byType(GestureDetector),
              )
              .first,
        )
        .onTap;
    await tester.longPress(find.text('0.00012345 BTC'));
    await tester.pumpAndSettle();
    action?.call();
    await tester.pumpAndSettle();
    expect(writes, [BitcoinUnit.btc, BitcoinUnit.sats]);
    expect(find.text('Amounts displayed in sats everywhere'), findsOneWidget);
  });

  testWidgets('a failed Undo keeps the current default and local choice', (
    tester,
  ) async {
    final writes = <BitcoinUnit>[];
    final source = ValueNotifier(snapshot());
    await tester.pumpWidget(
      host(
        Column(children: [amount('a'), amount('b')]),
        preferences: source,
        writer: (unit) async {
          writes.add(unit);
          return writes.length == 1;
        },
      ),
    );
    await tester.longPress(find.text('12,345 sats').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('0.00012345 BTC').first);
    await tester.pump();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(source.value.unit, BitcoinUnit.btc);
    expect(find.text('12,345 sats'), findsOneWidget);
    expect(find.text('0.00012345 BTC'), findsOneWidget);
    expect(
      find.text('Could not change the amount unit. Please try again.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    source.dispose();
  });

  testWidgets(
    'refreshes stay silent and an explicit tap announces only its displayed value',
    (tester) async {
      final events = <Map<dynamic, dynamic>>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
            dynamic message,
          ) async {
            if (message is Map) events.add(message);
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility,
              null,
            ),
      );
      await tester.pumpWidget(
        host(BullAmount(key: const ValueKey('a'), magnitude: Sats.fromInt(1))),
      );
      await tester.pumpWidget(
        host(BullAmount(key: const ValueKey('a'), magnitude: Sats.fromInt(2))),
      );
      expect(events.where((event) => event['type'] == 'announce'), isEmpty);
      await tester.tap(find.text('2 sats'));
      await tester.pump();
      final announcements = events
          .where((event) => event['type'] == 'announce')
          .toList();
      expect(announcements, hasLength(1));
      expect(
        (announcements.single['data'] as Map)['message'],
        '0.00000002 BTC',
      );
    },
  );
  testWidgets('successful Undo announces the restored default', (tester) async {
    final messages = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (dynamic event) async {
        if (event is Map && event['type'] == 'announce') {
          messages.add((event['data'] as Map)['message'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(
            SystemChannels.accessibility,
            null,
          ),
    );
    await tester.pumpWidget(host(amount('a')));
    await tester.longPress(find.text('12,345 sats'));
    await tester.pumpAndSettle();
    expect(messages, ['Amounts displayed in BTC everywhere']);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(messages, [
      'Amounts displayed in BTC everywhere',
      'Amounts displayed in sats everywhere',
    ]);
  });
}
