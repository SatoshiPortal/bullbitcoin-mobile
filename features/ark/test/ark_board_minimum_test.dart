import 'package:ark/ark.dart';
import 'package:bull_ark/ark_setup.dart';
import 'package:bull_ark/src/domain/ark_board_minimum.dart';
import 'package:bull_ark/src/domain/ark_display_data_port.dart';
import 'package:bull_ark/src/ui/ark_board_amount_screen.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullInputText;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show app, config;
import 'ark_operations_test.dart' show account;

void main() {
  test('minimum is optional, expires with its observation and binds full configuration', () {
    final captured = config();
    final observed = DateTime.utc(2026, 11, 19);
    final minimum = ArkBoardMinimum.fromSnapshot(
      captured,
      ArkSnapshot(
        account: account(),
        revision: 2,
        observedAt: observed,
        stale: false,
        serverInfo: ArkServerInfo(
          publicKey: 'public',
          minimumBoard: Sats.fromInt(50000),
        ),
      ),
    );
    expect(minimum?.forConfig(captured, now: observed), Sats.fromInt(50000));
    expect(
      minimum?.forConfig(
        captured,
        now: observed.add(const Duration(minutes: 5)),
      ),
      isNull,
    );
    expect(
      minimum?.forConfig(
        captured,
        now: observed.subtract(const Duration(seconds: 1)),
      ),
      isNull,
    );
    final changed = ArkAccountConfig(
      id: captured.id,
      arkUrl: captured.arkUrl,
      primaryEsploraUrl: Uri.parse('https://different-provider.example'),
      renewalThresholdBlocks: captured.renewalThresholdBlocks,
    );
    expect(minimum?.forConfig(changed, now: observed), isNull);
    expect(
      ArkBoardMinimum.fromSnapshot(
        captured,
        ArkSnapshot(
          account: account(),
          revision: 2,
          observedAt: observed,
          stale: true,
          serverInfo: ArkServerInfo(
            publicKey: 'public',
            minimumBoard: Sats.fromInt(50000),
          ),
        ),
      ),
      isNull,
    );
    expect(
      ArkBoardMinimum.fromSnapshot(
        captured,
        ArkSnapshot(
          account: account(),
          revision: 2,
          observedAt: observed,
          stale: false,
        ),
      ),
      isNull,
    );
  });

  testWidgets(
    'minimum applies to funding amount without a guessed network fee',
    (tester) async {
      final captured = config();
      final calls = <Sats>[];
      await tester.pumpWidget(
        app(
          ArkBoardAmountScreen(
            config: captured,
            minimum: ArkBoardMinimum(
              config: captured,
              minimum: Sats.fromInt(50000),
              observedAt: DateTime.now(),
            ),
            displayData: ArkDisplayData(
              account: account(),
              walletId: 'source',
              available: Sats.fromInt(50000),
            ),
            onReviewRequest: (_, amount) => calls.add(amount),
          ),
        ),
      );
      await tester.pumpAndSettle();
      void edit(String raw) => tester
          .widget<BullInputText>(find.byType(BullInputText))
          .onChanged(raw);
      BullButton action() =>
          tester.widget<BullButton>(find.widgetWithText(BullButton, 'Board'));
      edit('49999');
      await tester.pump();
      expect(action().disabled, isTrue);
      action().onPressed();
      expect(calls, isEmpty);
      edit('50000');
      await tester.pump();
      expect(
        action().disabled,
        isFalse,
        reason: 'Do not add a guessed miner fee to the server minimum',
      );
      expect(find.text('Fee estimate unavailable'), findsOneWidget);
      final maximum = tester.widget<BullButton>(
        find.widgetWithText(BullButton, 'Max'),
      );
      expect(maximum.disabled, isTrue);
      maximum.onPressed();
      expect(calls, isEmpty);
      action().onPressed();
      expect(calls, [Sats.fromInt(50000)]);
    },
  );

  testWidgets(
    'minimum expiry visibly removes the local block without editing',
    (tester) async {
      final captured = config();
      final observedAt = DateTime.now().subtract(
        const Duration(minutes: 4, seconds: 50),
      );
      final calls = <Sats>[];
      void review(ArkAccountConfig _, Sats amount) => calls.add(amount);
      ArkBoardAmountScreen screen(DateTime observed) => ArkBoardAmountScreen(
        config: captured,
        minimum: ArkBoardMinimum(
          config: captured,
          minimum: Sats.fromInt(50000),
          observedAt: observed,
        ),
        onReviewRequest: review,
      );
      BullButton action() =>
          tester.widget<BullButton>(find.widgetWithText(BullButton, 'Board'));
      await tester.pumpWidget(app(screen(observedAt)));
      tester
          .widget<BullInputText>(find.byType(BullInputText))
          .onChanged('1000');
      await tester.pump();
      expect(action().disabled, isTrue);
      final oldReview = action().onPressed;
      expect(find.textContaining('Amount is too low'), findsOneWidget);
      await tester.pump(const Duration(seconds: 11));
      expect(action().disabled, isFalse);
      expect(find.textContaining('Amount is too low'), findsNothing);
      expect(find.text('Minimum amount unavailable'), findsOneWidget);
      expect(calls, isEmpty, reason: 'Expiry must never submit automatically');
      oldReview();
      expect(calls, isEmpty, reason: 'The expired render is retired');
      // Rebuilding the same observation must not renew its elapsed deadline.
      await tester.pumpWidget(app(screen(observedAt)));
      expect(action().disabled, isFalse);
      // A new server observation may advise a minimum again.
      await tester.pumpWidget(app(screen(DateTime.now())));
      expect(action().disabled, isTrue);
      expect(find.textContaining('Amount is too low'), findsOneWidget);
      expect(calls, isEmpty);
    },
  );

  testWidgets('fresh refusal minimum supersedes an older observation', (
    tester,
  ) async {
    final captured = config();
    var calls = 0;
    await tester.pumpWidget(
      app(
        ArkBoardAmountScreen(
          config: captured,
          minimum: ArkBoardMinimum(
            config: captured,
            minimum: Sats.fromInt(50000),
            observedAt: DateTime.now().subtract(const Duration(minutes: 1)),
          ),
          failure: ArkBoardBelowMinimumFailure(Sats.fromInt(54321)),
          onReviewRequest: (_, _) => calls++,
        ),
      ),
    );
    tester.widget<BullInputText>(find.byType(BullInputText)).onChanged('52000');
    await tester.pump();
    final action = tester.widget<BullButton>(
      find.widgetWithText(BullButton, 'Board'),
    );
    expect(action.disabled, isTrue);
    action.onPressed();
    expect(calls, 0);
  });
}
