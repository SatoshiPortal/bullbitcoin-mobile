import 'dart:async';

import 'package:bb_mobile/features/wallet/data/ark_display_data.dart';
import 'package:bull_ark/src/ui/ark_board_amount_screen.dart';
import 'package:bull_ui/bull_ui.dart' show BullAmountScope, BullAmountSnapshot;
import 'package:bull_ui/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:primitives/primitives.dart';

import 'ark_board_source_test_support.dart';

T _ok<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err() => throw StateError('Cold source unavailable: ${result.runtimeType}'),
};

void main() {
  testWidgets(
    'ordinary Board entry scans a cold local zero to 100000 without funding',
    (tester) => navigateBoardSource(tester),
  );
  testWidgets(
    'ordinary Board source failed scan retries on the same mounted form',
    (tester) => navigateBoardSource(tester, retry: true),
  );
}

Future<void> navigateBoardSource(
  WidgetTester tester, {
  bool retry = false,
}) async {
  await tester.runAsync(() async {
    final (
      runtime: runtime,
      source: source,
      row: row,
      metadata: _,
      opened: opened,
      server: server,
      connections: connections,
      funding: funding,
    ) = await boardSourceRig();
    final display = WalletArkDisplayData(
      runtime: runtime,
      account: opened.account,
      currencyChanges: const Stream.empty(),
      selectedSource: (_) async => Ok(row.id),
      currency: () async => 'unsupported-fixture-currency',
      isActive: () => true,
    );
    final local = _ok(await display.read(opened.account));
    expect(
      local.available,
      Sats.zero,
      reason: 'The SDK starts empty before any network scan',
    );
    await display.close();
    var scans = 0;
    final subscription = source.started.listen((_) => scans++);
    final router = GoRouter(
      initialLocation: '/ark',
      routes: opened.feature.routes,
    );
    try {
      await tester.pumpWidget(
        MaterialApp.router(
          theme: ThemeData(extensions: testBullExtensions),
          routerConfig: router,
          builder: (_, child) => BullAmountScope(
            snapshot: const BullAmountSnapshot(
              unit: BitcoinUnit.sats,
              hideAmounts: false,
              isReady: true,
            ),
            writeUnit: (_) async => false,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final board = find.text('Board to Ark');
      // Settings owns the named navigation action; no direct form construction.
      await tester.ensureVisible(board);
      if (retry) connections.urls[0] = 'tcp://127.0.0.1:1';
      await tester.tap(board);
      await tester.pumpAndSettle();
      expect(
        find.text('Available on-chain'),
        findsOneWidget,
        reason: 'The ordinary amount form must be reached before Red',
      );
      await Future<void>.delayed(Duration.zero);
      final mountedForm = tester.state(find.byType(ArkBoardAmountScreen));
      if (retry) {
        final deadline = Stopwatch()..start();
        while ((scans == 0 || source.isSyncing()) &&
            deadline.elapsed < const Duration(seconds: 30)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(scans, 1);
        expect(find.textContaining('100,000'), findsNothing);
        connections.urls[0] = server.url;
        await tester.tap(find.text('Refresh'));
      }
      final elapsed = Stopwatch()..start();
      while (find.textContaining('100,000').evaluate().isEmpty &&
          elapsed.elapsed < const Duration(seconds: 30)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
      expect(
        find.textContaining('100,000'),
        findsOneWidget,
        reason:
            'Form reached; source scans=$scans, syncing=${source.isSyncing()}, waited=${elapsed.elapsed}',
      );
      expect(scans, retry ? 2 : 1);
      expect(
        tester.state(find.byType(ArkBoardAmountScreen)),
        same(mountedForm),
      );
      expect(funding.calls, isEmpty);
      expect(
        (await server.requests()).counts['blockchain.transaction.broadcast'] ??
            0,
        0,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await subscription.cancel();
    }
  });
}
