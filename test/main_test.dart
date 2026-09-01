import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/main.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPayjoinLifecycle extends Mock implements PayjoinLifecycle {}

class _MockWalletFacade extends Mock implements WalletFacade {}

void main() {
  test('resumes Payjoin recovery when the app returns to the foreground', () {
    final lifecycle = _MockPayjoinLifecycle();
    when(lifecycle.resume).thenAnswer((_) async => const Ok(null));

    resumePayjoinsOnAppResume(AppLifecycleState.paused, lifecycle);
    verifyNever(lifecycle.resume);

    resumePayjoinsOnAppResume(AppLifecycleState.resumed, lifecycle);
    verify(lifecycle.resume).called(1);
  });

  group('wallet lock on app lifecycle', () {
    late _MockWalletFacade wallet;

    setUp(() {
      wallet = _MockWalletFacade();
      when(wallet.lockPrivateWalletSession).thenReturn(true);
      when(wallet.takePendingLockNavigationRequest).thenReturn(false);
    });

    // iOS can go `active → inactive → hidden → paused`, and the user can
    // force-quit from the app switcher during `inactive`, so every step away
    // from the foreground has to clear.
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      test('clears private material immediately on ${state.name}', () {
        expect(applyWalletLockOnAppLifecycle(state, wallet), isFalse);

        verify(wallet.lockPrivateWalletSession).called(1);
        // Navigation waits for a frame the user can see.
        verifyNever(wallet.takePendingLockNavigationRequest);
      });
    }

    test('navigates on resume when the background lock asked for it', () {
      when(wallet.takePendingLockNavigationRequest).thenReturn(true);

      expect(
        applyWalletLockOnAppLifecycle(AppLifecycleState.resumed, wallet),
        isTrue,
      );

      verifyNever(wallet.lockPrivateWalletSession);
    });

    test('does not navigate on resume when nothing was locked', () {
      expect(
        applyWalletLockOnAppLifecycle(AppLifecycleState.resumed, wallet),
        isFalse,
      );
    });

    test('leaves the session alone while the app is in the foreground', () {
      expect(
        applyWalletLockOnAppLifecycle(AppLifecycleState.detached, wallet),
        isFalse,
      );

      verifyZeroInteractions(wallet);
    });
  });
}
