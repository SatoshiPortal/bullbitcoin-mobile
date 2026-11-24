import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/presentation/ark_cubit.dart';
import 'package:bull_ark/src/ui/ark_activity_list.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullDetailsTable, BullDetailsTableItem, Navigator;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show NavigatorState;
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
      (i) => i.label == 'Status',
    ))
      table.items.whereType<BullDetailsTableItem>().toList(),
];
String? value(List<BullDetailsTableItem> row, String label) =>
    row.singleWhere((i) => i.label == label).displayValue;

/// Opens each observed row's detail sheet in turn and returns its facts.
Future<List<List<BullDetailsTableItem>>> details(WidgetTester tester) async {
  final result = <List<BullDetailsTableItem>>[];
  final count = find.byType(ArkActivityTile).evaluate().length;
  for (var i = 0; i < count; i++) {
    final tile = find.byType(ArkActivityTile).at(i);
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    result.addAll(rows(tester));
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
  }
  return result;
}

void main() {
  testWidgets('rows group by local day and expose kind, status and amount', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final client = Client()
      ..snapshot = Ok(
        observed([
          movement(
            id: 'boarded',
            kind: ArkMovementKind.board,
            status: ArkMovementStatus.successful,
            amount: Sats.fromInt(50000),
            time: DateTime(2026, 11, 4, 12),
          ),
          movement(id: 'undated', amount: Sats.fromInt(5000)),
        ]),
      );
    await tester.pumpWidget(app(screen(controller(client), [])));
    await frame(tester);
    expect(find.byType(ArkActivityTile), findsNWidgets(2));
    expect(find.text('November 4'), findsOneWidget);
    expect(find.text('Date unavailable'), findsOneWidget);
    expect(find.text('50,000 sats'), findsOneWidget);
    expect(find.text('Board'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'\bCompleted\b')), findsOneWidget);
    expect(rows(tester), isEmpty);
    handle.dispose();
  });
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
      expect(rows(tester), isEmpty);
      // A plain payment carries no label; every other kind does.
      expect(find.text('Payment'), findsNothing);
      for (final label in [
        'Board',
        'Renewal',
        'Exit',
        'Lightning',
        'Unknown',
      ]) {
        expect(find.text(label), findsWidgets);
      }
      // Unsettled movements stay on their day; only the row says Pending.
      expect(find.text('November 16'), findsOneWidget);
      expect(find.text('Date unavailable'), findsOneWidget);
      final actual = await details(tester);
      expect(actual, hasLength(6));
      List<BullDetailsTableItem> forIndex(int i) => actual.singleWhere(
        (row) => row.any((item) => item.displayValue == '1,00$i sats'),
      );
      for (var i = 0; i < 6; i++) {
        final row = forIndex(i);
        final incoming = switch (data[i].kind) {
          ArkMovementKind.board || ArkMovementKind.lightningReceive => true,
          _ => false,
        };
        final pending = data[i].status == ArkMovementStatus.pending;
        // As the app's transaction details: money coming in shows what was
        // received; anything else what was sent and its fee, plus, while
        // pending, what arrives after that fee.
        expect(
          value(row, incoming ? 'Amount received' : 'Amount sent'),
          '1,00$i sats',
        );
        // Exits pay on-chain, which Bark does not record as a movement fee.
        final feeShown = !incoming && data[i].kind != ArkMovementKind.exit;
        expect(row.any((item) => item.label == 'Transaction Fee'), feeShown);
        if (feeShown) expect(value(row, 'Transaction Fee'), '1$i sats');
        if (!incoming && pending) {
          expect(value(row, 'Amount received'), '990 sats');
        }
        expect(
          value(row, 'Status'),
          ['Pending', 'Completed', 'Failed', 'Unknown'][i % 4],
        );
        expect(value(row, incoming ? 'To wallet' : 'From wallet'), 'Ark');
        final txid = row.where((item) => item.label == 'Transaction ID');
        expect(
          txid.map((item) => item.copyValue),
          i == 0 ? ['supplied-public-txid'] : isEmpty,
        );
        // Only a settled movement's own time is shown; none is invented.
        expect(row.any((item) => item.label == 'Date'), false);
        expect(row.any((item) => item.label == 'Confirmation time'), false);
      }
      expect(client.calls, ['read']);
      expect(calls, isEmpty);
      expect(
        tester.widgetList<BullButton>(find.byType(BullButton)),
        hasLength(2),
      );
      expect(find.text('No transactions yet.'), findsNothing);
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
      final actual = await details(tester);
      expect(actual, hasLength(2));
      for (final row in actual) {
        expect(value(row, 'Amount sent'), 'Unavailable');
        // Blank ids, a missing amount after fee and a missing time are left
        // out; a fee that was observed is shown, even when it is 0.
        for (final label in ['Transaction ID', 'Amount received', 'Date']) {
          expect(row.any((item) => item.label == label), false);
        }
      }
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
          expect(find.text('No transactions yet.'), findsOneWidget);
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
      expect(find.byType(ArkActivityTile), findsOneWidget);
      for (final label in ['Send', 'Receive']) {
        expect(button(tester, label).disabled, true);
        button(tester, label).onPressed();
      }
      expect(calls, isEmpty);
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
        expect(find.byType(ArkActivityTile), findsNothing);
        expect(find.text('foreign'), findsNothing);
        expect(find.text('No transactions yet.'), findsNothing);
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
      oldReply.complete(
        Ok(
          observed([movement(id: 'old-private-row', amount: Sats.fromInt(66))]),
        ),
      );
      await frame(tester);
      expect(find.byType(ArkActivityTile), findsNothing);
      newReply.complete(
        Ok(observed([movement(id: 'current-row', amount: Sats.fromInt(77))])),
      );
      await frame(tester);
      final current = await details(tester);
      expect(current, hasLength(1));
      expect(value(current.single, 'Amount sent'), '77 sats');
      expect(find.text('66 sats'), findsNothing);
      expect(a.isClosed, false);
      expect(b.isClosed, false);
    },
  );

  testWidgets('a pending renewal reads like a pending app transaction', (
    tester,
  ) async {
    final client = Client()
      ..snapshot = Ok(
        observed([
          ArkMovement(
            id: 'renewal',
            kind: ArkMovementKind.renewal,
            status: ArkMovementStatus.pending,
            amount: Sats.fromInt(80000),
            fee: Sats.fromInt(1048),
            sentTo: ['tark1qpendingdestinationaddress00'],
          ),
        ]),
      );
    await tester.pumpWidget(app(screen(controller(client), [])));
    await frame(tester);
    final row = (await details(tester)).single;
    expect(row.map((item) => item.label), [
      'From wallet',
      'Address',
      'Amount sent',
      'Amount received',
      'Transaction Fee',
      'Status',
    ]);
    expect(value(row, 'Amount sent'), '80,000 sats');
    expect(value(row, 'Amount received'), '78,952 sats');
    expect(
      row.singleWhere((item) => item.label == 'Address').copyValue,
      'tark1qpendingdestinationaddress00',
    );
  });

  testWidgets('a completed board reads like a received app transaction', (
    tester,
  ) async {
    final client = Client()
      ..snapshot = Ok(
        observed([
          ArkMovement(
            id: 'board',
            kind: ArkMovementKind.board,
            status: ArkMovementStatus.successful,
            amount: Sats.fromInt(50000),
            fee: Sats.zero,
            transactionId: 'board-funding-txid',
            receivedOn: ['tark1qboardreceivedonaddress0000'],
            createdAt: DateTime.utc(2026, 11, 20, 9),
            completedAt: DateTime.utc(2026, 11, 20, 10),
          ),
        ]),
      );
    await tester.pumpWidget(app(screen(controller(client), [])));
    await frame(tester);
    final row = (await details(tester)).single;
    expect(row.map((item) => item.label), [
      'Transaction ID',
      'To wallet',
      'Address',
      'Amount received',
      'Status',
      'Confirmation time',
    ]);
    expect(value(row, 'Amount received'), '50,000 sats');
  });

  testWidgets('days read Today and Yesterday, then dates', (tester) async {
    final now = DateTime.now();
    final client = Client()
      ..snapshot = Ok(
        observed([
          movement(
            id: 'today',
            status: ArkMovementStatus.pending,
            amount: Sats.fromInt(1),
            time: now,
          ),
          movement(
            id: 'yesterday',
            status: ArkMovementStatus.successful,
            amount: Sats.fromInt(2),
            time: DateTime(now.year, now.month, now.day - 1, 12),
          ),
          movement(
            id: 'earlier',
            status: ArkMovementStatus.successful,
            amount: Sats.fromInt(3),
            time: DateTime(now.year - 1, 3, 5, 12),
          ),
        ]),
      );
    await tester.pumpWidget(app(screen(controller(client), [])));
    await frame(tester);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('March 5, ${now.year - 1}'), findsOneWidget);
    // The pending movement is listed under Today, its row saying Pending.
    expect(find.text('Pending'), findsOneWidget);
  });

  testWidgets('a Board left before funding is not listed', (tester) async {
    final client = Client()
      ..snapshot = Ok(
        observed([
          movement(
            id: 'abandoned',
            kind: ArkMovementKind.board,
            status: ArkMovementStatus.failed,
            amount: Sats.zero,
            time: DateTime(2026, 11, 4, 12),
          ),
          movement(
            id: 'boarded',
            kind: ArkMovementKind.board,
            status: ArkMovementStatus.successful,
            amount: Sats.fromInt(29670),
            time: DateTime(2026, 11, 4, 13),
          ),
          movement(
            id: 'failed-with-funds',
            kind: ArkMovementKind.board,
            status: ArkMovementStatus.failed,
            amount: Sats.fromInt(19670),
            time: DateTime(2026, 11, 4, 14),
          ),
        ]),
      );
    await tester.pumpWidget(app(screen(controller(client), [])));
    await frame(tester);
    expect(find.byType(ArkActivityTile), findsNWidgets(2));
    expect(find.text('0 sats'), findsNothing);
    expect(find.text('29,670 sats'), findsOneWidget);
    // A failed Board that moved funds stays visible.
    expect(find.text('19,670 sats'), findsOneWidget);
  });
}
