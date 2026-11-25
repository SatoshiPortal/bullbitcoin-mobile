import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transactions/transactions.dart';

void main() {
  final navigator = GlobalKey<NavigatorState>();
  late List<String> calls;
  late Completer<void>? gate;
  late int running;
  late int maxRunning;
  late bool Function() lastIsActive;

  Future<void> poll(
    String walletId, {
    required bool Function() isActive,
  }) async {
    calls.add(walletId);
    lastIsActive = isActive;
    running++;
    if (running > maxRunning) maxRunning = running;
    try {
      await gate?.future;
    } finally {
      running--;
    }
  }

  setUp(() {
    calls = [];
    gate = null;
    running = 0;
    maxRunning = 0;
  });

  PageRoute<void> page(Widget child) => PageRouteBuilder<void>(
    pageBuilder: (_, _, _) => child,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );

  final params = ValueNotifier<({bool active, bool isLiquid, String? id})>((
    active: true,
    isLiquid: false,
    id: 'w',
  ));

  Future<void> pump(
    WidgetTester tester, {
    bool active = true,
    bool isLiquid = false,
    String? walletId = 'w',
  }) async {
    params.value = (active: active, isLiquid: isLiquid, id: walletId);
    if (tester.any(find.byType(SettlementSyncPoller))) return tester.pump();
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        navigatorKey: navigator,
        onGenerateRoute: (_) => page(
          ValueListenableBuilder(
            valueListenable: params,
            builder: (_, p, _) => SettlementSyncPoller(
              walletId: p.id,
              active: p.active,
              isLiquid: p.isLiquid,
              poll: poll,
              child: const SizedBox(),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('polls at once then every 60 s for Bitcoin', (tester) async {
    await pump(tester);
    expect(calls, ['w']);
    await tester.pump(const Duration(seconds: 59));
    expect(calls, hasLength(1));
    await tester.pump(const Duration(seconds: 1));
    expect(calls, hasLength(2));
    await tester.pump(const Duration(seconds: 60));
    expect(calls, hasLength(3));
  });

  testWidgets('polls every 20 s for Liquid', (tester) async {
    await pump(tester, isLiquid: true);
    expect(calls, hasLength(1));
    await tester.pump(const Duration(seconds: 20));
    expect(calls, hasLength(2));
  });

  testWidgets('does not poll while inactive or without a wallet', (
    tester,
  ) async {
    await pump(tester, active: false);
    await tester.pump(const Duration(minutes: 5));
    expect(calls, isEmpty);
    await pump(tester, walletId: null);
    await tester.pump(const Duration(minutes: 5));
    expect(calls, isEmpty);
  });

  testWidgets('stops when active turns false and restarts when true', (
    tester,
  ) async {
    await pump(tester);
    expect(calls, hasLength(1));
    final stale = lastIsActive;
    await pump(tester, active: false);
    expect(stale(), isFalse);
    await tester.pump(const Duration(minutes: 5));
    expect(calls, hasLength(1));
    await pump(tester);
    expect(calls, hasLength(2));
  });

  testWidgets('never overlaps and waits for the pass to finish', (
    tester,
  ) async {
    gate = Completer<void>();
    await pump(tester, isLiquid: true);
    await tester.pump(const Duration(minutes: 5));
    expect(calls, hasLength(1));
    gate!.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 19));
    expect(calls, hasLength(1));
    await tester.pump(const Duration(seconds: 1));
    expect(calls, hasLength(2));
    expect(maxRunning, 1);
  });

  testWidgets('stops under a pushed route and resumes when it is popped', (
    tester,
  ) async {
    await pump(tester, isLiquid: true);
    expect(calls, hasLength(1));
    unawaited(navigator.currentState!.push(page(const SizedBox())));
    await tester.pump();
    await tester.pump(const Duration(minutes: 5));
    expect(calls, hasLength(1));
    navigator.currentState!.pop();
    await tester.pump();
    expect(calls, hasLength(2));
  });

  testWidgets('stops while the app is backgrounded', (tester) async {
    await pump(tester, isLiquid: true);
    expect(calls, hasLength(1));
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump(const Duration(minutes: 5));
    expect(calls, hasLength(1));
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(calls, hasLength(2));
  });

  testWidgets('stops on dispose', (tester) async {
    await pump(tester);
    final isActive = lastIsActive;
    await tester.pumpWidget(const SizedBox());
    expect(isActive(), isFalse);
    await tester.pump(const Duration(minutes: 5));
    expect(calls, hasLength(1));
  });
}
