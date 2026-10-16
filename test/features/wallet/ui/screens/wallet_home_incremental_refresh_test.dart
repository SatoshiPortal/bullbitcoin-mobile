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
      'automatic incremental sync never shows spinner or starts user refresh (mounted=$alreadyRunning)',
      (tester) async {
        await harness.mount(
          tester,
          WalletState(
            status: WalletStatus.success,
            isRefreshing: alreadyRunning,
          ),
        );
        if (!alreadyRunning) {
          harness.states.add(
            const WalletState(status: WalletStatus.success, isRefreshing: true),
          );
          await tester.pump();
        }
        await tester.pump();
        for (var frame = 0; frame < 6; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pump();
        expect(tester.takeException(), isNull);
        await harness.capture(tester, 'incremental-$alreadyRunning');
        verifyNever(() => harness.wallet.refresh());
        expect(find.byType(RefreshProgressIndicator), findsNothing);
        verify(() => harness.wallet.add(const WalletRefreshed())).called(1);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
