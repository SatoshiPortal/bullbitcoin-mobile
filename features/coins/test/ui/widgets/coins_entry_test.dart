import 'dart:async';

import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:coins/coins.dart';
import 'package:coins/setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

typedef SummaryResult = Result<CoinSummary, CoinsFailure>;

class Harness {
  final events = StreamController<void>.broadcast();
  final requests = <(String, Completer<SummaryResult>)>[];
  final opens = <(String, Completer<void>)>[];

  Future<SummaryResult> load(String id) {
    final completer = Completer<SummaryResult>();
    requests.add((id, completer));
    return completer.future;
  }

  Widget build(String id) => MaterialApp(
    theme: AppTheme.themeData(AppThemeType.light),
    localizationsDelegates: [
      CoinsLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
      ...bullUiLocalizationsDelegates,
    ],
    supportedLocales: CoinsLocalizations.supportedLocales,
    home: BullAmountScope(
      snapshot: const BullAmountSnapshot(
        unit: BitcoinUnit.sats,
        hideAmounts: false,
        isReady: true,
      ),
      writeUnit: (_) async => true,
      child: CoinsEntry(
        walletId: id,
        label: 'Manage coins',
        loadCoinSummary: load,
        syncCompletions: events.stream,
        onOpen: (_, id) {
          final completer = Completer<void>();
          opens.add((id, completer));
          return completer.future;
        },
      ),
    ),
  );

  void complete(int index, int count) =>
      requests[index].$2.complete(Ok((count: count, frozenSat: BigInt.zero)));
}

void main() {
  testWidgets(
    'loads initially and retains summary during sync and open reloads',
    (tester) async {
      final h = Harness();
      addTearDown(h.events.close);
      await tester.pumpWidget(h.build('watch-only'));
      expect(h.requests.map((r) => r.$1), ['watch-only']);
      expect(find.byType(CoinsEntrySubtitle), findsNothing);
      h.complete(0, 3);
      await tester.pump();
      expect(
        tester
            .widget<CoinsEntrySubtitle>(find.byType(CoinsEntrySubtitle))
            .utxoCount,
        3,
      );
      h.events.add(null);
      await tester.pump();
      expect(h.requests.length, 2);
      expect(
        tester
            .widget<CoinsEntrySubtitle>(find.byType(CoinsEntrySubtitle))
            .utxoCount,
        3,
      );
      h.requests[1].$2.complete(const Err(CoinsLoadFailure()));
      await tester.pump();
      expect(
        tester
            .widget<CoinsEntrySubtitle>(find.byType(CoinsEntrySubtitle))
            .utxoCount,
        3,
      );
      await tester.tap(find.text('Manage coins'));
      expect(h.opens.single.$1, 'watch-only');
      h.opens.single.$2.complete();
      await tester.pump();
      expect(h.requests.length, 3);
      expect(
        tester
            .widget<CoinsEntrySubtitle>(find.byType(CoinsEntrySubtitle))
            .utxoCount,
        3,
      );
      h.complete(2, 4);
      await tester.pump();
      expect(
        tester
            .widget<CoinsEntrySubtitle>(find.byType(CoinsEntrySubtitle))
            .utxoCount,
        4,
      );
    },
  );

  testWidgets('ignores stale reads, replacement and disposed results', (
    tester,
  ) async {
    final h = Harness();
    addTearDown(h.events.close);
    await tester.pumpWidget(h.build('a'));
    h.events.add(null);
    await tester.pump();
    h.complete(1, 2);
    await tester.pump();
    h.complete(0, 1);
    await tester.pump();
    expect(
      tester
          .widget<CoinsEntrySubtitle>(find.byType(CoinsEntrySubtitle))
          .utxoCount,
      2,
    );
    h.events.add(null);
    await tester.pump();
    await tester.pumpWidget(h.build('b'));
    expect(find.byType(CoinsEntrySubtitle), findsNothing);
    expect(h.requests.last.$1, 'b');
    h.complete(2, 8);
    await tester.pump();
    expect(find.byType(CoinsEntrySubtitle), findsNothing);
    h.complete(3, 5);
    await tester.pump();
    expect(
      tester
          .widget<CoinsEntrySubtitle>(find.byType(CoinsEntrySubtitle))
          .utxoCount,
      5,
    );
    h.events.add(null);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    h.complete(4, 6);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'opening an old wallet cannot reload a replacement, even after switching back',
    (tester) async {
      final h = Harness();
      addTearDown(h.events.close);
      await tester.pumpWidget(h.build('a'));
      await tester.tap(find.text('Manage coins'));
      await tester.pumpWidget(h.build('b'));
      await tester.pumpWidget(h.build('a'));
      expect(h.requests.length, 3);
      h.opens.single.$2.complete();
      await tester.pump();
      expect(h.requests.length, 3);
    },
  );
}
