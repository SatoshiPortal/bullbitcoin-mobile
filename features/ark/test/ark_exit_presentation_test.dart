import 'package:ark/ark.dart';
import 'package:bull_ark/generated/l10n/ark_localizations.dart';
import 'package:bull_ark/src/ui/ark_exit_hold_button.dart';
import 'package:bull_ark/src/presentation/ark_operation_cubit.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_exits_screen_test.dart' as exits;
import 'ark_information_widget_test.dart' show app;
import 'ark_operation_review_screen_test.dart' as review;

void main() {
  testWidgets('empty exits has only the useful start action', (tester) async {
    final h = exits.Harness(exits.view(rows: [], exits: ArkExitStatus.none));
    await tester.pumpWidget(app(h.screen));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(BullButton, 'Review'), findsNothing);
    expect(
      find.widgetWithText(BullButton, 'Progress emergency exits'),
      findsNothing,
    );
    expect(
      find.widgetWithText(BullButton, 'Start emergency exit'),
      findsOneWidget,
    );
    expect(h.untouched, isTrue);
  });
  for (final stale in [false, true]) {
    testWidgets('named progression keeps stale=$stale admission', (
      tester,
    ) async {
      final h = exits.Harness(exits.view(stale: stale));
      await tester.pumpWidget(app(h.screen));
      await tester.pumpAndSettle();
      final target = find.widgetWithText(
        BullButton,
        'Progress emergency exits',
      );
      expect(target, findsOneWidget);
      final button = tester.widget<BullButton>(target);
      expect(button.disabled, stale);
      final context = tester.element(target);
      expect(button.bgColor, context.bull.secondary);
      expect(button.textColor, context.bull.onSecondary);
      button.onPressed();
      expect(h.progress, stale ? 0 : 1);
      expect(h.exits, 0);
      expect(h.claims, isEmpty);
      final claim = find.widgetWithText(BullButton, 'Claim');
      expect(claim, findsOneWidget);
      tester.widget<BullButton>(claim).onPressed();
      expect(
        h.claims,
        stale
            ? isEmpty
            : [
                ['shared'],
              ],
      );
    });
  }
  for (final language in ['en', 'fr']) {
    testWidgets(
      'renewal $language has its exact title and grouped reviewed amounts',
      (tester) async {
        final rig = review.Rig();
        await rig.ready(amount: 120000);
        await tester.pumpWidget(app(rig.screen, language: language));
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(BullTopBar));
        final loc = ArkLocalizations.of(context);
        if (loc == null) throw StateError('Missing Ark localization');
        final top = tester.widget<BullTopBar>(find.byType(BullTopBar));
        expect(top.title, loc.renew);
        expect(find.text(loc.renew), findsOneWidget);
        final facts = review.details(tester);
        expect(facts[loc.amount], language == 'en' ? '120,000' : '120 000');
        expect(facts[loc.netInSats], language == 'en' ? '119,900' : '119 900');
        expect(facts[loc.feeInSats], '100');
        final destination = tester
            .widgetList<BullDetailsTableItem>(find.byType(BullDetailsTableItem))
            .singleWhere((row) => row.label == loc.destination);
        expect(destination.displayValue, 'reviewed-destination');
        expect(destination.copyValue, 'reviewed-destination');
        expect(rig.client.calls, ['quote']);
        expect(rig.ids, 0);
      },
    );
  }
  for (final language in ['en', 'fr']) {
    for (final exposure in <int?>[12000, 0, null]) {
      testWidgets(
        'exit $language quoted caps and exposure $exposure remain exact',
        (tester) async {
          final request = ArkQuoteRequest.emergencyExit(
            ids: ['selected-vtxo'],
            destination: 'full-reviewed-return-destination',
            feeRate: FeeRate(2),
            maxClaimFee: Sats.fromInt(1072),
          );
          final rig = review.Rig(request: request);
          rig.client.quoted = Ok(
            ArkQuote(
              id: 'bound-review',
              account: rig.cubit.account,
              generation: 2,
              chainSource: Uri.parse('http://localhost:3000'),
              configGeneration: 1,
              kind: ArkOperationKind.emergencyExit,
              amount: Sats.fromInt(509400),
              fee: Sats.fromInt(10596),
              net: Sats.fromInt(498804),
              selectedIds: ['selected-vtxo'],
              destination: 'full-reviewed-return-destination',
              feeRate: FeeRate(2),
              maxClaimFee: Sats.fromInt(1072),
              confirmedReserveExposure: exposure == null
                  ? null
                  : Sats.fromInt(exposure),
              observedTip: 100,
              validUntil: DateTime.utc(2030),
            ),
          );
          await rig.cubit.load();
          await tester.pumpWidget(app(rig.screen, language: language));
          await tester.pumpAndSettle();
          final context = tester.element(find.byType(BullTopBar));
          final loc = ArkLocalizations.of(context);
          if (loc == null) throw StateError('Missing Ark localization');
          expect(
            tester.widget<BullTopBar>(find.byType(BullTopBar)).title,
            loc.exitReviewTitle,
          );
          final facts = review.details(tester);
          expect(facts[loc.amount], language == 'en' ? '509,400' : '509 400');
          expect(facts[loc.feeInSats], language == 'en' ? '10,596' : '10 596');
          expect(
            facts[loc.netInSats],
            language == 'en' ? '498,804' : '498 804',
          );
          expect(
            facts[loc.exitMaximumClaimFee],
            language == 'en' ? '1,072' : '1 072',
          );
          expect(
            facts[loc.exitProgressReserveExposure],
            exposure == null
                ? loc.unknown
                : exposure == 0
                ? '0'
                : language == 'en'
                ? '12,000'
                : '12 000',
          );
          expect(facts[loc.exitProgressFeeRate], '2.0');
          final destination = tester
              .widgetList<BullDetailsTableItem>(
                find.byType(BullDetailsTableItem),
              )
              .singleWhere((row) => row.label == loc.exitIntendedDestination);
          expect(destination.displayValue, 'full-reviewed-return-destination');
          expect(destination.copyValue, destination.displayValue);
          // The zero fixture only checks display, not native fundability.
          if (exposure != 0) {
            expect(
              tester
                  .widget<ArkExitHoldButton>(find.byType(ArkExitHoldButton))
                  .enabled,
              exposure != null,
            );
          }
          expect(rig.client.calls, ['quote']);
          expect(rig.ids, 0);
        },
      );
    }
  }
  for (final mismatch in ['kind', 'account', 'loading']) {
    testWidgets(
      'generic review title survives $mismatch instead of inventing a matching intent',
      (tester) async {
        final rig = review.Rig(
          request: mismatch == 'kind'
              ? ArkQuoteRequest.exitProgress(feeRate: FeeRate(2))
              : null,
        );
        final account = rig.cubit.account;
        final observed = mismatch == 'account'
            ? ArkAccountId(
                parent: Fingerprint('aabbccdd'),
                network: account.network,
                serverIdentity: account.serverIdentity,
              )
            : account;
        rig.cubit.emit(
          mismatch == 'loading'
              ? const ArkOperationLoading()
              : ArkOperationReview(review.reviewed(observed)),
        );
        await tester.pumpWidget(app(rig.screen));
        await tester.pumpAndSettle();
        expect(
          tester.widget<BullTopBar>(find.byType(BullTopBar)).title,
          'Review',
        );
        expect(find.text('Review'), findsOneWidget);
        expect(rig.client.calls, isEmpty);
        expect(rig.ids, 0);
      },
    );
  }
}
