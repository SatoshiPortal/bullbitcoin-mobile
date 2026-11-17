import 'package:ark/ark.dart';
import 'package:bull_ark/src/ui/ark_exit_progress_fee_screen.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullInputText, SizedBox, Widget;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show app, config;
import 'ark_operations_test.dart' show account;

BullButton review(WidgetTester tester) =>
    tester.widget<BullButton>(find.widgetWithText(BullButton, 'Review'));
BullInputText input(WidgetTester tester) =>
    tester.widget<BullInputText>(find.byType(BullInputText));
Future<void> edit(WidgetTester tester, String raw) async {
  input(tester)
      .onChanged(raw); // Bypass formatters to exercise full validation.
  await tester.pump();
}

void main() {
  testWidgets(
    'absent host stays unavailable, passive and explicitly in sat/vB',
    (tester) async {
      await tester.pumpWidget(app(ArkExitProgressFeeScreen(config: config())));
      await tester.pump();
      expect(review(tester).disabled, true);
      expect(
        find.text('This Ark action is unavailable in this build.'),
        findsOneWidget,
      );
      expect(input(tester).hint, 'Fee rate (sat/vB)');
      expect(find.textContaining('00112233/regtest/'), findsOneWidget);
      expect(
        find.text(
          'Exit and fee spending require foreground review. Background maintenance never starts or progresses an exit.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Progress may expose the account-wide confirmed exit reserve. A future review must show the actual fee and reserve at risk.',
        ),
        findsOneWidget,
      );
      expect(find.text('0 sat/vB'), findsNothing);
      expect(find.text('Slow'), findsNothing);
      await edit(tester, '42');
      expect(review(tester).disabled, true);
      expect(() => review(tester).onPressed(), returnsNormally);
    },
  );

  for (final raw in [
    '',
    '0',
    '-1',
    '1.5',
    ' 1',
    '1 ',
    '1\n',
    '١',
    '1e3',
    'NaN',
    'Infinity',
    '9007199254740993',
    '9007199254740992',
    '9' * 400,
  ]) {
    testWidgets('invalid raw rate ${raw.codeUnits} never hands off', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        app(
          ArkExitProgressFeeScreen(
            config: config(),
            onReviewRequest: (_, _) => ++calls,
          ),
        ),
      );
      await edit(tester, raw);
      expect(review(tester).disabled, true);
      review(tester).onPressed();
      expect(calls, 0);
      expect(input(tester).value, raw);
    });
  }

  for (final raw in ['1', '00042', '9007199254740991']) {
    testWidgets('valid $raw forwards exact config and integer once', (
      tester,
    ) async {
      final supplied = config();
      final events = <(ArkAccountConfig, FeeRate)>[];
      void handler(ArkAccountConfig c, FeeRate rate) => events.add((c, rate));
      Widget screen() => app(
        ArkExitProgressFeeScreen(config: supplied, onReviewRequest: handler),
      );
      await tester.pumpWidget(screen());
      await tester.pumpWidget(screen());
      expect(events, isEmpty);
      await edit(tester, raw);
      expect(events, isEmpty);
      final button = review(tester);
      expect(button.disabled, false);
      button.onPressed();
      button.onPressed();
      expect(events, hasLength(1));
      expect(identical(events.single.$1, supplied), true);
      expect(events.single.$2.satsPerVbyte, BigInt.parse(raw).toDouble());
      expect(BigInt.from(events.single.$2.satsPerVbyte), BigInt.parse(raw));
      expect(events.single.$2.satsPerVbyte.isFinite, true);
      await tester.pump();
      expect(input(tester).disabled, true);
      expect(review(tester).disabled, true);
    });
  }

  testWidgets('edit A to B to A never resurrects old review or input closure', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      app(
        ArkExitProgressFeeScreen(
          config: config(),
          onReviewRequest: (_, _) => ++calls,
        ),
      ),
    );
    await edit(tester, '42');
    final stale = review(tester);
    final staleInput = input(tester);
    await edit(tester, '43');
    await edit(tester, '42');
    stale.onPressed();
    staleInput.onChanged('99');
    await tester.pump();
    expect(input(tester).value, '42');
    expect(calls, 0);
    review(tester).onPressed();
    expect(calls, 1);
  });

  final original = config();
  final replacements = <String, ArkAccountConfig>{
    'parent': ArkAccountConfig(
      id: ArkAccountId(
        parent: Fingerprint('aabbccdd'),
        network: account().network,
        serverIdentity: account().serverIdentity,
      ),
      arkUrl: original.arkUrl,
      primaryEsploraUrl: original.primaryEsploraUrl,
      fallbackEsploraUrl: original.fallbackEsploraUrl,
    ),
    'network': ArkAccountConfig(
      id: ArkAccountId(
        parent: account().parent,
        network: BitcoinNetwork.mainnet,
        serverIdentity: account().serverIdentity,
      ),
      arkUrl: original.arkUrl,
      primaryEsploraUrl: original.primaryEsploraUrl,
      fallbackEsploraUrl: original.fallbackEsploraUrl,
    ),
    'identity': ArkAccountConfig(
      id: ArkAccountId(
        parent: account().parent,
        network: account().network,
        serverIdentity: 'other-server',
      ),
      arkUrl: original.arkUrl,
      primaryEsploraUrl: original.primaryEsploraUrl,
      fallbackEsploraUrl: original.fallbackEsploraUrl,
    ),
    'ark URL': ArkAccountConfig(
      id: account(),
      arkUrl: Uri.parse('https://other.example'),
      primaryEsploraUrl: original.primaryEsploraUrl,
      fallbackEsploraUrl: original.fallbackEsploraUrl,
    ),
    'chain URL': ArkAccountConfig(
      id: account(),
      arkUrl: original.arkUrl,
      primaryEsploraUrl: Uri.parse('https://other.example'),
      fallbackEsploraUrl: original.fallbackEsploraUrl,
    ),
    'fallback': config(fallback: false),
    'threshold': ArkAccountConfig(
      id: account(),
      arkUrl: original.arkUrl,
      primaryEsploraUrl: original.primaryEsploraUrl,
      fallbackEsploraUrl: original.fallbackEsploraUrl,
      renewalThresholdBlocks: 999,
    ),
  };
  for (final entry in replacements.entries) {
    testWidgets(
      '${entry.key} A to B to A invalidates old callbacks and clears draft',
      (tester) async {
        var calls = 0;
        void handler(ArkAccountConfig _, FeeRate rate) => ++calls;
        Widget screen(ArkAccountConfig c) =>
            app(ArkExitProgressFeeScreen(config: c, onReviewRequest: handler));
        await tester.pumpWidget(screen(original));
        await edit(tester, '42');
        final old = review(tester);
        await tester.pumpWidget(screen(entry.value));
        expect(input(tester).value, '');
        await tester.pumpWidget(screen(original));
        await edit(tester, '42');
        old.onPressed();
        expect(calls, 0);
        review(tester).onPressed();
        expect(calls, 1);
      },
    );
  }

  testWidgets('handler A to null to B to A does not revive rendered review', (
    tester,
  ) async {
    final events = <String>[];
    void a(ArkAccountConfig _, FeeRate rate) => events.add('a');
    void b(ArkAccountConfig _, FeeRate rate) => events.add('b');
    Future<void> mount(
      void Function(ArkAccountConfig, FeeRate)? handler,
    ) => tester.pumpWidget(
      app(ArkExitProgressFeeScreen(config: original, onReviewRequest: handler)),
    );
    await mount(a);
    await edit(tester, '42');
    final stale = review(tester);
    await mount(null);
    expect(review(tester).disabled, true);
    await mount(b);
    await mount(a);
    stale.onPressed();
    expect(events, isEmpty);
    review(tester).onPressed();
    expect(events, ['a']);
  });

  for (final throws in [false, true]) {
    testWidgets(
      'consumption survives ${throws ? 'throw' : 'return'}, edits and every rebinding',
      (tester) async {
        var calls = 0;
        void handler(ArkAccountConfig _, FeeRate rate) {
          ++calls;
          if (throws) throw StateError('delegate refused');
        }

        void other(ArkAccountConfig _, FeeRate rate) => ++calls;
        Widget screen(
          ArkAccountConfig c,
          void Function(ArkAccountConfig, FeeRate)? callback,
        ) =>
            app(ArkExitProgressFeeScreen(config: c, onReviewRequest: callback));
        await tester.pumpWidget(screen(original, handler));
        await edit(tester, '42');
        final staleInput = input(tester);
        final old = review(tester);
        if (throws) {
          expect(old.onPressed, throwsStateError);
        } else {
          old.onPressed();
        }
        expect(old.onPressed, returnsNormally);
        staleInput.onChanged('99');
        await tester.pumpWidget(screen(config(fallback: false), null));
        await tester.pumpWidget(screen(original, other));
        await tester.pumpWidget(screen(original, handler));
        input(tester).onChanged('43');
        review(tester).onPressed();
        await tester.pump();
        expect(calls, 1);
        expect(review(tester).disabled, true);
        expect(input(tester).disabled, true);
        // A genuinely NEW State is a new form, not an automatic retry.
        await tester.pumpWidget(app(const SizedBox.shrink()));
        await tester.pumpWidget(screen(original, other));
        await edit(tester, '43');
        expect(review(tester).disabled, false);
      },
    );
  }

  testWidgets('direct disposal refuses otherwise current callbacks', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      app(
        ArkExitProgressFeeScreen(
          config: original,
          onReviewRequest: (_, _) => ++calls,
        ),
      ),
    );
    await edit(tester, '42');
    final old = review(tester);
    final oldInput = input(tester);
    await tester.pumpWidget(app(const SizedBox.shrink()));
    expect(old.onPressed, returnsNormally);
    expect(() => oldInput.onChanged('43'), returnsNormally);
    expect(calls, 0);
  });
  // Coalesced input regression: one current handler receives both edits.
  // The existing app/config/input/review helpers are shared prerequisites.
  testWidgets('one current input closure accepts two edits before a frame', (
    tester,
  ) async {
    final events = <(ArkAccountConfig, FeeRate)>[];
    final supplied = config();
    await tester.pumpWidget(
      app(
        ArkExitProgressFeeScreen(
          config: supplied,
          onReviewRequest: (c, rate) => events.add((c, rate)),
        ),
      ),
    );
    final current = input(tester).onChanged;
    current('4');
    current('42'); // Deliberately no await/pump between current input events.
    expect(events, isEmpty);
    await tester.pump();
    expect(input(tester).value, '42');
    expect(review(tester).disabled, false);
    review(tester).onPressed();
    expect(events, hasLength(1));
    expect(identical(events.single.$1, supplied), true);
    expect(events.single.$2.satsPerVbyte, 42.0);
  });
}
