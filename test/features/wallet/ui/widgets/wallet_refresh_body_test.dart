import 'dart:async';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_refresh_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final initiallyRefreshing in [true, false]) {
    testWidgets(
      'show awaits existing sync (already running=$initiallyRefreshing)',
      (tester) async {
        final gate = Completer<void>();
        var requests = 0;
        var waits = 0;
        Widget build(bool refreshing) => MaterialApp(
          home: Scaffold(
            body: WalletRefreshBody(
              isRefreshing: refreshing,
              waitForRefresh: () {
                waits++;
                return gate.future;
              },
              onRefresh: () async {
                requests++;
              },
              slivers: const [SliverToBoxAdapter(child: SizedBox(height: 200))],
            ),
          ),
        );
        await tester.pumpWidget(build(initiallyRefreshing));
        if (!initiallyRefreshing) {
          await tester.pumpWidget(build(true));
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(
          requests,
          0,
          reason: 'show must not enqueue another pass or fetch price',
        );
        expect(waits, 1);
        expect(find.byType(RefreshProgressIndicator), findsOneWidget);
        await tester.pumpWidget(build(true));
        expect(waits, 1);
        gate.complete();
        await tester.pumpWidget(build(false));
        await tester.pumpAndSettle();
        expect(find.byType(RefreshProgressIndicator), findsNothing);
      },
    );
  }

  testWidgets('a real pull requests one refresh', (tester) async {
    final gate = Completer<void>();
    var requests = 0;
    var waits = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WalletRefreshBody(
            isRefreshing: false,
            waitForRefresh: () async {
              waits++;
            },
            onRefresh: () {
              requests++;
              return gate.future;
            },
            slivers: const [SliverToBoxAdapter(child: SizedBox(height: 800))],
          ),
        ),
      ),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(requests, 1);
    expect(waits, 0);
    gate.complete();
    await tester.pumpAndSettle();
  });
}
