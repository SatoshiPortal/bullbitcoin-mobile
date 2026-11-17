import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/presentation/ark_cubit.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullDetailsTable, BullDetailsTableItem;
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

List<List<BullDetailsTableItem>> rows(WidgetTester tester) => [
  for (final table in tester.widgetList<BullDetailsTable>(
    find.byType(BullDetailsTable),
  ))
    if (table.items.whereType<BullDetailsTableItem>().any(
      (i) => i.label == 'Identifier',
    ))
      table.items.whereType<BullDetailsTableItem>().toList(),
];
String? value(List<BullDetailsTableItem> row, String label) =>
    row.singleWhere((i) => i.label == label).displayValue;

void main() {
  testWidgets(
    'all kinds and statuses remain ordered observations with exact sats and no row actions',
    (tester) async {
      final data = [
        for (var i = 0; i < ArkMovementKind.values.length; i++)
          movement(
            id: i < 2 ? 'duplicate' : 'id-$i',
            kind: ArkMovementKind.values[i],
            status: ArkMovementStatus.values[i % 4],
            amount: Sats.fromInt(1000 + i),
            fee: Sats.fromInt(10 + i),
            txid: i == 0 ? 'supplied-public-txid' : null,
            time: i == 0
                ? DateTime.parse('2026-11-16T16:00:00+02:00')
                : i == 1
                ? DateTime.utc(2020)
                : null,
          ),
      ];
      final client = Client()..snapshot = Ok(observed(data));
      final calls = <String>[];
      await tester.pumpWidget(app(screen(controller(client), calls)));
      await frame(tester);
      expect(find.text('Observed activity'), findsOneWidget);
      for (final label in [
        'Board funding',
        'Payment',
        'Renewal',
        'Exit',
        'Lightning receipt',
        'Unknown',
      ]) {
        expect(find.text(label), findsWidgets);
      }
      final actual = rows(tester);
      expect(actual, hasLength(6));
      for (var i = 0; i < 6; i++) {
        expect(value(actual[i], 'Identifier'), data[i].id);
        expect(value(actual[i], 'Amount in sats'), '${1000 + i}');
        expect(value(actual[i], 'Fee (sats)'), '${10 + i}');
        expect(
          value(actual[i], 'Transaction ID'),
          i == 0 ? 'supplied-public-txid' : 'Unavailable',
        );
        expect(
          value(actual[i], 'State'),
          ['Pending', 'Completed', 'Failed', 'Unknown'][i % 4],
        );
        expect(actual[i].map((item) => item.copyValue), everyElement(isNull));
      }
      expect(
        value(actual[0], 'Observed time (UTC)'),
        '2026-11-16T14:00:00.000Z',
      );
      expect(
        value(actual[1], 'Observed time (UTC)'),
        '2020-01-01T00:00:00.000Z',
      );
      expect(value(actual[2], 'Observed time (UTC)'), 'Unavailable');
      expect(client.calls, ['read']);
      expect(calls, isEmpty);
      expect(
        tester.widgetList<BullButton>(find.byType(BullButton)),
        hasLength(7),
      );
      expect(find.text('Activity observations unavailable'), findsNothing);
    },
  );
  testWidgets(
    'missing fields are unavailable, not zero or snapshot observation time',
    (tester) async {
      final client = Client()
        ..snapshot = Ok(
          observed([
            movement(id: '', txid: ''),
            movement(id: '   ', txid: '   ', fee: Sats.fromInt(0)),
          ]),
        );
      await tester.pumpWidget(app(screen(controller(client), [])));
      await frame(tester);
      final actual = rows(tester);
      expect(actual, hasLength(2));
      for (final row in actual) {
        for (final label in [
          'Identifier',
          'Transaction ID',
          'Observed time (UTC)',
          'Amount in sats',
        ]) {
          expect(value(row, label), 'Unavailable');
        }
      }
      expect(value(actual[0], 'Fee (sats)'), 'Unavailable');
      expect(value(actual[1], 'Fee (sats)'), '0');
      expect(find.text('2026-11-17T00:00:00.000Z'), findsNothing);
    },
  );
  for (final stale in [false, true]) {
    for (final complete in [false, true]) {
      testWidgets(
        'empty history is unavailable stale=$stale completeVtxos=$complete even after complete recovery',
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
          expect(find.text('Observed activity'), findsOneWidget);
          expect(
            find.text('Activity observations unavailable'),
            findsOneWidget,
          );
          expect(
            find.text('No items in this observed inventory.'),
            findsNothing,
          );
          expect(rows(tester), isEmpty);
          expect(client.calls, ['read']);
        },
      );
    }
  }
  testWidgets(
    'failed refresh keeps stale=false activity explicitly historical and funded-off protective',
    (tester) async {
      final client = Client()
        ..snapshot = Ok(observed([movement()]))
        ..pass = const Err(ArkUnavailableFailure());
      final cubit = controller(client);
      final calls = <String>[];
      await tester.pumpWidget(app(screen(cubit, calls, enabled: false)));
      await frame(tester);
      await cubit.refresh();
      await frame(tester);
      expect((cubit.state as ArkViewFailed).lastObserved?.stale, false);
      expect(find.text(historical), findsOneWidget);
      expect(rows(tester), hasLength(1));
      for (final label in ['Send', 'Receive', 'Add funds']) {
        expect(button(tester, label).disabled, true);
        button(tester, label).onPressed();
      }
      expect(calls, isEmpty);
      for (final label in ['VTXOs', 'Emergency exit', 'Server information']) {
        button(tester, label).onPressed();
      }
      expect(calls, ['vtxos', 'exits', 'info']);
      expect(client.calls, ['read', 'sync']);
    },
  );
  for (final failed in [false, true]) {
    testWidgets(
      'foreign activity is suppressed in failed=$failed observations',
      (tester) async {
        final client = Client()..snapshot = Ok(observed([movement()]));
        final cubit = controller(client);
        await tester.pumpWidget(app(screen(cubit, [])));
        await frame(tester);
        final original = account();
        final foreign = observed(
          [movement(id: 'foreign')],
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
        expect(rows(tester), isEmpty);
        expect(find.text('foreign'), findsNothing);
        expect(find.text('Observed activity'), findsNothing);
      },
    );
  }
  testWidgets(
    'rebound owner never displays late old account rows while new read is pending',
    (tester) async {
      final oldReply = Completer<Result<ArkSnapshot, ArkWalletFailure>>();
      final newReply = Completer<Result<ArkSnapshot, ArkWalletFailure>>();
      final a = controller(Client()..readReply = oldReply);
      final b = controller(Client()..readReply = newReply);
      await tester.pumpWidget(app(screen(a, [])));
      await frame(tester);
      await tester.pumpWidget(app(screen(b, [])));
      await frame(tester);
      oldReply.complete(Ok(observed([movement(id: 'old-private-row')])));
      await frame(tester);
      expect(rows(tester), isEmpty);
      expect(find.text('old-private-row'), findsNothing);
      newReply.complete(Ok(observed([movement(id: 'current-row')])));
      await frame(tester);
      expect(rows(tester), hasLength(1));
      expect(find.text('current-row'), findsOneWidget);
      expect(a.isClosed, false);
      expect(b.isClosed, false);
    },
  );
}
