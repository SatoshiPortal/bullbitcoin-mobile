import 'package:ark/ark.dart';
import 'package:bull_ark/src/ui/ark_exits_screen.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullDetailsTable, BullDetailsTableItem, SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show app;
import 'ark_operations_test.dart' show account;

ArkExit exitRow({
  String id = 'shared',
  ArkExitStatus status = ArkExitStatus.claimable,
  int? height = 99,
  String? txid = 'observed-txid',
}) => ArkExit(
  id: id,
  amount: Sats.fromInt(1234),
  status: status,
  claimableHeight: height,
  claimTxid: txid,
);
ArkSnapshot view({
  ArkAccountId? owner,
  bool stale = false,
  int? tip = 100,
  ArkRecoveryStatus recovery = ArkRecoveryStatus.complete,
  ArkExitStatus exits = ArkExitStatus.claimable,
  List<ArkExit>? rows,
}) => ArkSnapshot(
  account: owner ?? account(),
  revision: 2,
  observedAt: DateTime.utc(2026, 11, 16),
  stale: stale,
  tipHeight: tip,
  recovery: recovery,
  exits: exits,
  exitDetails: rows ?? [exitRow()],
  vtxoCompleteness: ArkSectionCompleteness.unknown,
);

class Harness {
  ArkSnapshot snapshot;
  int exits = 0, progress = 0;
  final claims = <List<String>>[];
  Harness(this.snapshot);
  ArkExitsScreen get screen => ArkExitsScreen(
    snapshot: snapshot,
    onReviewExit: () => exits++,
    onReviewProgress: () => progress++,
    onReviewClaim: claims.add,
  );
  bool get untouched => exits == 0 && progress == 0 && claims.isEmpty;
}

List<BullButton> buttons(WidgetTester tester) =>
    tester.widgetList<BullButton>(find.byType(BullButton)).toList();
List<BullDetailsTableItem> items(WidgetTester tester) => [
  for (final table in tester.widgetList<BullDetailsTable>(
    find.byType(BullDetailsTable),
  ))
    ...table.items.whereType<BullDetailsTableItem>(),
];

void main() {
  testWidgets('read-only mount shows explicit sats and exact copy metadata', (
    tester,
  ) async {
    final h = Harness(view());
    await tester.pumpWidget(app(h.screen));
    expect(h.untouched, true);
    final amount = items(tester)
        .singleWhere((i) => i.label == 'Amount in sats');
    expect(amount.displayValue, '1234');
    final txid = items(tester)
        .singleWhere((i) => i.label == 'Claim transaction');
    expect(txid.displayValue, 'observed-txid');
    expect(txid.copyValue, txid.displayValue);
    expect(find.text('Exit claimable'), findsOneWidget);
  });
  testWidgets('explicit claim review emits exactly one immutable current ID', (
    tester,
  ) async {
    final h = Harness(
      view(
        rows: [
          exitRow(),
          exitRow(id: 'other'),
        ],
      ),
    );
    await tester.pumpWidget(app(h.screen));
    buttons(tester).first.onPressed();
    expect(h.claims, [
      ['shared'],
    ]);
    expect(() => h.claims.single.add('extra'), throwsUnsupportedError);
    expect(h.exits + h.progress, 0);
  });
  testWidgets(
    'old callbacks cannot cross account/server with identical row ID',
    (tester) async {
      final a = Harness(view());
      await tester.pumpWidget(app(a.screen));
      final old = buttons(tester).map((b) => b.onPressed).toList();
      final original = account();
      final b = Harness(
        view(
          owner: ArkAccountId(
            parent: original.parent,
            network: original.network,
            serverIdentity: 'different-server',
          ),
        ),
      );
      await tester.pumpWidget(app(b.screen));
      for (final callback in old) {
        callback();
      }
      expect(a.untouched, true);
      expect(b.untouched, true);
      buttons(tester).first.onPressed();
      expect(b.claims, [
        ['shared'],
      ]);
    },
  );
  testWidgets('same-account old row callback uses current handler', (
    tester,
  ) async {
    final a = Harness(view());
    await tester.pumpWidget(app(a.screen));
    final old = buttons(tester).first.onPressed;
    final b = Harness(view());
    await tester.pumpWidget(app(b.screen));
    old();
    expect(a.untouched, true);
    expect(b.claims, [
      ['shared'],
    ]);
  });
  for (final recovery in [
    ArkRecoveryStatus.unknown,
    ArkRecoveryStatus.incomplete,
    ArkRecoveryStatus.failed,
  ]) {
    testWidgets(
      'fresh protective review remains available with recovery $recovery',
      (tester) async {
        final h = Harness(view(recovery: recovery));
        await tester.pumpWidget(app(h.screen));
        for (final button in buttons(tester)) {
          expect(button.disabled, false);
          button.onPressed();
        }
        expect(h.claims, [
          ['shared'],
        ]);
        expect(h.exits, 1);
        expect(h.progress, 1);
      },
    );
  }
  for (final invalid in [
    view(stale: true),
    view(tip: null),
    view(exits: ArkExitStatus.unknown),
    view(exits: ArkExitStatus.failed),
  ]) {
    testWidgets(
      'old and rendered review callbacks refuse unavailable exit observation ${invalid.stale}/${invalid.tipHeight}/${invalid.exits}',
      (tester) async {
        final h = Harness(view());
        await tester.pumpWidget(app(h.screen));
        final old = buttons(tester).map((b) => b.onPressed).toList();
        h.snapshot = invalid;
        await tester.pumpWidget(app(h.screen));
        expect(find.text('shared'), findsOneWidget);
        for (final callback in old) {
          callback();
        }
        for (final button in buttons(tester)) {
          expect(button.disabled, true);
          button.onPressed();
        }
        expect(h.untouched, true);
      },
    );
  }
  for (final (label, rows) in <(String, List<ArkExit>)>[
    ('removed', []),
    ('pending', [exitRow(status: ArkExitStatus.pending)]),
    ('claimed', [exitRow(status: ArkExitStatus.claimed)]),
    ('unknown', [exitRow(status: ArkExitStatus.unknown)]),
    ('duplicate', [exitRow(), exitRow()]),
    ('empty-id', [exitRow(id: '')]),
  ]) {
    testWidgets('old row callback refuses current ID case: $label', (
      tester,
    ) async {
      final h = Harness(view());
      await tester.pumpWidget(app(h.screen));
      final old = buttons(tester).first.onPressed;
      h.snapshot = view(rows: rows);
      await tester.pumpWidget(app(h.screen));
      old();
      expect(h.claims, isEmpty);
    });
  }
  testWidgets('stale and uncertain empty differs from observed empty', (
    tester,
  ) async {
    for (final unknown in [
      view(rows: [], stale: true, exits: ArkExitStatus.none),
      view(rows: [], exits: ArkExitStatus.unknown),
      view(rows: [], exits: ArkExitStatus.pending),
    ]) {
      await tester.pumpWidget(app(Harness(unknown).screen));
      expect(find.text('No items in this observed inventory.'), findsNothing);
      expect(find.text('Unavailable'), findsWidgets);
    }
    await tester.pumpWidget(
      app(Harness(view(rows: [], exits: ArkExitStatus.none)).screen),
    );
    expect(find.text('No items in this observed inventory.'), findsOneWidget);
  });
  testWidgets(
    'missing height and txid remain unavailable without copy default',
    (tester) async {
      await tester.pumpWidget(
        app(Harness(view(rows: [exitRow(height: null, txid: null)])).screen),
      );
      final txid = items(tester)
          .singleWhere((i) => i.label == 'Claim transaction');
      expect(txid.displayValue, 'Unavailable');
      expect(txid.copyValue, isNull);
      expect(
        items(tester)
            .singleWhere((i) => i.label == 'Claimable at block')
            .displayValue,
        'Unavailable',
      );
    },
  );
  testWidgets(
    'all typed statuses are explicitly localized in English and French',
    (tester) async {
      final rows = [
        for (final status in ArkExitStatus.values)
          exitRow(id: status.name, status: status),
      ];
      for (final language in ['en', 'fr']) {
        await tester.pumpWidget(
          app(Harness(view(rows: rows)).screen, language: language),
        );
        final statuses = items(tester)
            .where((i) => i.label == (language == 'en' ? 'State' : 'État'))
            .map((i) => i.displayValue)
            .toSet();
        expect(
          statuses,
          language == 'en'
              ? {
                  'Unknown exit state',
                  'No exit observed',
                  'Exit pending',
                  'Exit claimable',
                  'Claim submitted',
                  'Exit claimed',
                  'Exit needs attention',
                }
              : {
                  'État de sortie inconnu',
                  'Aucune sortie observée',
                  'Sortie en attente',
                  'Sortie récupérable',
                  'Récupération soumise',
                  'Sortie récupérée',
                  'Sortie à vérifier',
                },
        );
      }
    },
  );
  testWidgets('captured callbacks refuse after disposal', (tester) async {
    final h = Harness(view());
    await tester.pumpWidget(app(h.screen));
    final old = buttons(tester).map((b) => b.onPressed).toList();
    await tester.pumpWidget(app(Harness(view()).screen, language: 'fr'));
    // Replace the whole screen type, rather than merely updating its account.
    await tester.pumpWidget(app(const SizedBox.shrink()));
    for (final callback in old) {
      callback();
    }
    expect(h.untouched, true);
  });
}
