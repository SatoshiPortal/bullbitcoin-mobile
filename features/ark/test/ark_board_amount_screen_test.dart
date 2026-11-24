import 'package:ark/ark.dart';
import 'package:bull_ark/src/domain/ark_display_data_port.dart';
import 'package:bull_ark/src/ui/ark_board_amount_screen.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BuildContext,
        BullButton,
        BullInputText,
        BullText,
        BullThemeX,
        SizedBox,
        Widget;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show app, config;
import 'ark_operations_test.dart' show account;

BuildContext context(WidgetTester tester) =>
    tester.element(find.byType(ArkBoardAmountScreen));
BullButton review(WidgetTester tester) =>
    tester.widget<BullButton>(find.widgetWithText(BullButton, 'Continue'));
BullInputText input(WidgetTester tester) =>
    tester.widget<BullInputText>(find.byType(BullInputText));
Future<void> edit(WidgetTester tester, String raw) async {
  input(tester)
      .onChanged(raw); // Bypass formatters to exercise full validation.
  await tester.pump();
}

void main() {
  testWidgets('absent host stays unavailable, passive and explicitly in sats', (
    tester,
  ) async {
    await tester.pumpWidget(app(ArkBoardAmountScreen(config: config())));
    await tester.pump();
    expect(review(tester).disabled, true);
    expect(
      find.text('This Ark action is unavailable in this build.'),
      findsOneWidget,
    );
    expect(input(tester).hint, '0');
    expect(find.textContaining('00112233/regtest/'), findsNothing);
    expect(find.text('Available on-chain'), findsOneWidget);
    expect(find.textContaining('fee policy'), findsNothing);
    expect(find.textContaining('funding review'), findsNothing);
    expect(find.textContaining('Max is unavailable'), findsNothing);
    expect(find.text('Ark info'), findsNothing);
    expect(find.textContaining('Minimum'), findsNothing);
    expect(find.text('0 sat'), findsNothing);
    expect(find.text('Slow'), findsNothing);
    await edit(tester, '42');
    expect(review(tester).disabled, true);
    expect(() => review(tester).onPressed(), returnsNormally);
  });

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
    '2100000000000001',
    '9' * 400,
  ]) {
    testWidgets('invalid raw amount ${raw.codeUnits} never hands off', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        app(
          ArkBoardAmountScreen(
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

  for (final raw in ['1', '00042', '2100000000000000']) {
    testWidgets('valid $raw forwards exact config and integer once', (
      tester,
    ) async {
      final supplied = config();
      final events = <(ArkAccountConfig, Sats)>[];
      void handler(ArkAccountConfig c, Sats amount) => events.add((c, amount));
      Widget screen() =>
          app(ArkBoardAmountScreen(config: supplied, onReviewRequest: handler));
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
      expect(events.single.$2.value, BigInt.parse(raw));
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
        ArkBoardAmountScreen(
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
        void handler(ArkAccountConfig _, Sats amount) => ++calls;
        Widget screen(ArkAccountConfig c) =>
            app(ArkBoardAmountScreen(config: c, onReviewRequest: handler));
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
    void a(ArkAccountConfig _, Sats amount) => events.add('a');
    void b(ArkAccountConfig _, Sats amount) => events.add('b');
    Future<void> mount(void Function(ArkAccountConfig, Sats)? handler) =>
        tester.pumpWidget(
          app(ArkBoardAmountScreen(config: original, onReviewRequest: handler)),
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
        void handler(ArkAccountConfig _, Sats amount) {
          ++calls;
          if (throws) throw StateError('delegate refused');
        }

        void other(ArkAccountConfig _, Sats amount) => ++calls;
        Widget screen(
          ArkAccountConfig c,
          void Function(ArkAccountConfig, Sats)? callback,
        ) => app(ArkBoardAmountScreen(config: c, onReviewRequest: callback));
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
        ArkBoardAmountScreen(
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
    final events = <(ArkAccountConfig, Sats)>[];
    final supplied = config();
    await tester.pumpWidget(
      app(
        ArkBoardAmountScreen(
          config: supplied,
          onReviewRequest: (c, amount) => events.add((c, amount)),
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
    expect(events.single.$2.value, BigInt.from(42));
  });

  testWidgets('the server minimum is the only help under the amount', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        ArkBoardAmountScreen(
          config: config(),
          minimumBoard: Sats.fromInt(20000),
          onReviewRequest: (_, _) {},
        ),
      ),
    );
    await tester.pump();
    BullText minimumLine() => tester.widget<BullText>(
      find.widgetWithText(BullText, 'Minimum: 20,000 sats'),
    );
    expect(minimumLine().color, isNot(context(tester).bull.error));
    expect(review(tester).disabled, true);

    // Below the minimum: the line turns red and Board stays off, live.
    await edit(tester, '19999');
    expect(minimumLine().color, context(tester).bull.error);
    expect(review(tester).disabled, true);

    // At the minimum: Board is offered and the line is plain again.
    await edit(tester, '20000');
    expect(minimumLine().color, isNot(context(tester).bull.error));
    expect(review(tester).disabled, false);

    // Another error shows on its own line; the minimum stays visible.
    await edit(tester, '1.5');
    expect(find.text('Minimum: 20,000 sats'), findsOneWidget);
    expect(
      find.text(
        'Enter a positive whole amount in sats within the Bitcoin supply limit.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('preparing keeps the balance the user saw, never Unavailable', (
    tester,
  ) async {
    ArkDisplayData display(Sats? available) => ArkDisplayData(
      account: config().id,
      walletId: 'secure',
      available: available,
    );
    Widget screen({required bool busy, Sats? available}) => app(
      ArkBoardAmountScreen(
        config: config(),
        displayData: display(available),
        busy: busy,
      ),
    );
    await tester.pumpWidget(screen(busy: false, available: Sats.fromInt(5000)));
    await tester.pump();
    expect(find.text('5,000 sats'), findsOneWidget);
    // Preparing reserves the coin: the live balance becomes unknown.
    await tester.pumpWidget(screen(busy: true));
    await tester.pump();
    expect(find.text('5,000 sats'), findsOneWidget);
    expect(find.text('Unavailable'), findsNothing);
    // Back to editing, the live value is shown again, unknown included.
    await tester.pumpWidget(screen(busy: false));
    await tester.pump();
    expect(find.text('Unavailable'), findsOneWidget);
  });
}
