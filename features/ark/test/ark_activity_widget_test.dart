import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/presentation/ark_cubit.dart';
import 'package:bull_ui/bull_ui.dart' show ValueKey, Semantics;
import 'package:intl/intl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_account_screen_test.dart'
    show Client, controller, screen, historical, button;
import 'ark_information_widget_test.dart' show app;
import 'ark_operations_test.dart' show account;

ArkSnapshot observed(
  List<ArkMovement> movements, {
  ArkAccountId? owner,
  bool stale = false,
  ArkSectionCompleteness completeness = ArkSectionCompleteness.unknown,
}) => ArkSnapshot(
  account: owner ?? account(),
  revision: 2,
  observedAt: DateTime.utc(2026, 11, 17),
  movements: movements,
  stale: stale,
  recovery: ArkRecoveryStatus.complete,
  vtxoCompleteness: completeness,
  renewal: ArkRenewalStatus.current,
);
ArkMovement movement({
  String id = 'record',
  String? txid,
  DateTime? time,
  ArkMovementKind kind = ArkMovementKind.payment,
  ArkMovementStatus status = ArkMovementStatus.unknown,
  Sats? amount,
  Sats? fee,
}) => ArkMovement(
  id: id,
  kind: kind,
  status: status,
  transactionId: txid,
  createdAt: time,
  amount: amount,
  fee: fee,
);
Future<void> frame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Finder activityRows() => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics && widget.properties.label == 'Observed activity',
);

void main() {
  testWidgets(
    'compact observations group genuine dates without technical identifiers',
    (tester) async {
      final time = DateTime(2026, 11, 4, 12, 30);
      final movements = [
        movement(
          id: 'private-record-one',
          txid: 'public-but-technical-txid',
          time: time,
          kind: ArkMovementKind.board,
          status: ArkMovementStatus.successful,
          amount: Sats.fromInt(50000),
        ),
        movement(
          id: 'private-record-two',
          time: time.add(const Duration(hours: 1)),
          kind: ArkMovementKind.payment,
          status: ArkMovementStatus.pending,
          amount: Sats.fromInt(5000),
        ),
        movement(id: 'unknown-date'),
      ];
      final client = Client()..snapshot = Ok(observed(movements));
      await tester.pumpWidget(app(screen(controller(client), [])));
      await frame(tester);
      expect(tester.takeException(), isNull);
      expect(activityRows(), findsNWidgets(3));
      expect(find.text(DateFormat.yMMMMd('en').format(time)), findsOneWidget);
      expect(find.text('50,000 sats'), findsOneWidget);
      expect(find.text('5,000 sats'), findsOneWidget);
      expect(find.text('Payment'), findsNWidgets(2));
      for (final (anchor, labels) in [
        ('50,000 sats', ['Boarded', '12:30']),
        ('5,000 sats', ['Payment', 'Pending', '13:30']),
        ('Unknown', ['Payment', 'Unavailable']),
      ]) {
        final row = find.ancestor(
          of: find.text(anchor),
          matching: activityRows(),
        );
        expect(row, findsOneWidget);
        for (final label in labels) {
          expect(
            find.descendant(of: row, matching: find.text(label)),
            findsOneWidget,
          );
        }
      }
      final boarded = find.ancestor(
        of: find.text('50,000 sats'),
        matching: activityRows(),
      );
      expect(
        find.descendant(
          of: boarded,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Completed',
          ),
        ),
        findsOneWidget,
      );
      for (final raw in [
        'private-record-one',
        'private-record-two',
        'public-but-technical-txid',
        'Identifier',
        'Transaction ID',
        'Observed time (UTC)',
      ]) {
        expect(find.text(raw), findsNothing);
      }
      expect(
        find.text(DateFormat.yMMMMd('en').format(DateTime(2026, 11, 17))),
        findsNothing,
      );
      expect(client.calls, ['read']);
    },
  );

  testWidgets(
    'every observed kind and status stays visible with unknown fields explicit',
    (tester) async {
      final data = [
        for (var i = 0; i < ArkMovementKind.values.length; i++)
          movement(
            id: 'technical-$i',
            kind: ArkMovementKind.values[i],
            status:
                ArkMovementStatus.values[i % ArkMovementStatus.values.length],
            amount: i == 0 ? null : Sats.fromInt(1000 + i),
          ),
      ];
      final client = Client()..snapshot = Ok(observed(data));
      await tester.pumpWidget(app(screen(controller(client), [])));
      await frame(tester);
      expect(tester.takeException(), isNull);
      expect(activityRows(), findsNWidgets(6));
      for (final label in [
        'Board funding',
        'Payment',
        'Renewal',
        'Exit',
        'Lightning receipt',
        'Unknown',
        'Pending',
        'Failed',
        'Unavailable',
      ]) {
        expect(find.text(label), findsWidgets);
      }
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Completed',
        ),
        findsNWidgets(2),
      );
      expect(find.text('1,001 sats'), findsOneWidget);
      expect(find.text('0 sats'), findsNothing);
      expect(find.text('technical-0'), findsNothing);
      expect(client.calls, ['read']);
    },
  );

  for (final stale in [false, true]) {
    for (final complete in [false, true]) {
      testWidgets(
        'empty history remains unavailable stale=$stale completeVtxos=$complete',
        (tester) async {
          final client = Client()
            ..snapshot = Ok(
              observed(
                [],
                stale: stale,
                completeness: complete
                    ? ArkSectionCompleteness.complete
                    : ArkSectionCompleteness.unknown,
              ),
            );
          await tester.pumpWidget(app(screen(controller(client), [])));
          await frame(tester);
          expect(
            find.byKey(const ValueKey('ark-empty-activity')),
            findsOneWidget,
          );
          expect(
            find.text('Activity observations unavailable'),
            findsOneWidget,
          );
          expect(find.text('No transactions yet'), findsNothing);
          expect(activityRows(), findsNothing);
          expect(client.calls, ['read']);
        },
      );
    }
  }

  testWidgets('failed refresh preserves historical activity and off guards', (
    tester,
  ) async {
    final client = Client()
      ..snapshot = Ok(observed([movement()]))
      ..pass = const Err(ArkUnavailableFailure());
    final cubit = controller(client);
    final calls = <String>[];
    await tester.pumpWidget(app(screen(cubit, calls, enabled: false)));
    await frame(tester);
    await cubit.refresh();
    await frame(tester);
    expect(find.text(historical), findsOneWidget);
    expect(activityRows(), findsOneWidget);
    for (final label in ['Send', 'Receive']) {
      expect(button(tester, label).disabled, isTrue);
      button(tester, label).onPressed();
    }
    expect(calls, isEmpty);
    expect(client.calls, ['read', 'sync']);
  });

  for (final failed in [false, true]) {
    testWidgets('foreign activity suppressed failed=$failed', (tester) async {
      final client = Client()..snapshot = Ok(observed([movement()]));
      final cubit = controller(client);
      await tester.pumpWidget(app(screen(cubit, [])));
      await frame(tester);
      final original = account();
      final foreign = observed(
        [movement(amount: Sats.fromInt(987654))],
        owner: ArkAccountId(
          parent: original.parent,
          network: original.network,
          serverIdentity: 'foreign',
        ),
      );
      cubit.emit(
        failed
            ? ArkViewFailed(
                const ArkServiceUnavailableFailure(),
                lastObserved: foreign,
              )
            : ArkObserved(foreign),
      );
      await frame(tester);
      expect(activityRows(), findsNothing);
      expect(find.text('987,654 sats'), findsNothing);
    });
  }

  testWidgets(
    'rebound owner rejects late rows and displays only its current observation',
    (tester) async {
      final oldReply = Completer<Result<ArkSnapshot, ArkWalletFailure>>();
      final newReply = Completer<Result<ArkSnapshot, ArkWalletFailure>>();
      final a = controller(Client()..readReply = oldReply);
      final b = controller(Client()..readReply = newReply);
      await tester.pumpWidget(app(screen(a, [])));
      await frame(tester);
      await tester.pumpWidget(app(screen(b, [])));
      await frame(tester);
      oldReply.complete(Ok(observed([movement(amount: Sats.fromInt(111))])));
      await frame(tester);
      expect(activityRows(), findsNothing);
      newReply.complete(Ok(observed([movement(amount: Sats.fromInt(222))])));
      await frame(tester);
      expect(activityRows(), findsOneWidget);
      expect(find.text('222 sats'), findsOneWidget);
      expect(find.text('111 sats'), findsNothing);
      expect(a.isClosed, false);
      expect(b.isClosed, false);
    },
  );
}
