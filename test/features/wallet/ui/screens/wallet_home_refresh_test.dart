import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'helpers/wallet_home_harness.dart';

void main() {
  late WalletHomeHarness harness;
  setUp(() => harness = WalletHomeHarness());
  tearDown(() => harness.dispose());
  for (final alreadyRunning in [false, true]) {
    testWidgets(
      'automatic discovery shows spinner without requesting sync (mounted=$alreadyRunning)',
      (tester) async {
        await harness.mount(
          tester,
          WalletState(
            status: WalletStatus.success,
            isDiscovering: alreadyRunning,
          ),
        );
        if (!alreadyRunning) {
          harness.states.add(
            const WalletState(
              status: WalletStatus.success,
              isDiscovering: true,
            ),
          );
          await tester.pump();
        }
        for (var frame = 0; frame < 6; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull);
        expect(find.byType(RefreshProgressIndicator), findsOneWidget);
        verifyNever(() => harness.wallet.refresh());
        await harness.capture(tester, 'discovery-$alreadyRunning');
        harness.states.add(const WalletState(status: WalletStatus.success));
        await tester.pump();
        for (var frame = 0; frame < 6; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pump();
        expect(find.byType(RefreshProgressIndicator), findsNothing);
        verifyNever(() => harness.wallet.refresh());
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('a user pull keeps its native spinner without a second refresh', (
    tester,
  ) async {
    await harness.mount(
      tester,
      const WalletState(status: WalletStatus.success),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 600));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    verify(() => harness.wallet.refresh()).called(1);
    harness.states.add(
      const WalletState(status: WalletStatus.success, isDiscovering: true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    verifyNever(() => harness.wallet.refresh());
    harness.states.add(const WalletState(status: WalletStatus.success));
    harness.refresh.complete();
    await tester.pump();
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump();
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('consecutive discoveries keep a visibly sized spinner', (
    tester,
  ) async {
    await harness.mount(
      tester,
      const WalletState(status: WalletStatus.success, isDiscovering: true),
    );
    await tester.pump(const Duration(milliseconds: 300));
    harness.states.add(const WalletState(status: WalletStatus.success));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    harness.states.add(
      const WalletState(status: WalletStatus.success, isDiscovering: true),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    final box = tester.renderObject<RenderBox>(
      find.byType(RefreshProgressIndicator),
    );
    expect(
      box.getTransformTo(null).entry(0, 0).abs(),
      greaterThan(.9),
      reason: 'A following wallet scan must retain a visibly sized spinner',
    );
    harness.states.add(const WalletState(status: WalletStatus.success));
    await tester.pumpWidget(const SizedBox());
  });
}
