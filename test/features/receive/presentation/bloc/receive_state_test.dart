import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for [ReceiveState.isPayjoinFlowOwningNavigation] — the getter the
/// receive ShellRoute's generic "payment received" navigation defers to, so
/// it doesn't race ReceivePayjoinInProgressScreen's own navigation (a real
/// payjoin completion auto-navigates there; a plain-broadcast fallback
/// completion stays on that screen for a manual "View Details" tap).
void main() {
  PayjoinReceiver payjoinWith({required PayjoinStatus status}) =>
      Payjoin.receiver(
            status: status,
            id: 'pj1',
            isTestnet: true,
            walletId: 'w1',
            pjUri: 'bitcoin:tb1qtest?pj=https://payjo.in',
            createdAt: DateTime(2026),
            expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
          )
          as PayjoinReceiver;

  Wallet localWallet() => Wallet(
    origin: 'test-origin',
    network: Network.bitcoinMainnet,
    xpubFingerprint: '00000000',
    scriptType: ScriptType.bip84,
    xpub: '',
    externalPublicDescriptor: '',
    internalPublicDescriptor: '',
    signer: SignerEntity.local,
    signerDevice: null,
    balanceSat: BigInt.zero,
  );

  group('ReceiveState.isPayjoinFlowOwningNavigation', () {
    test('false for a non-Bitcoin receive type, even with a payjoin set', () {
      final state = ReceiveState(
        type: ReceiveType.liquid,
        payjoin: payjoinWith(status: PayjoinStatus.requested),
      );

      expect(state.isPayjoinFlowOwningNavigation, isFalse);
    });

    test('false when there is no payjoin session at all (watch-only '
        'wallet)', () {
      const state = ReceiveState(type: ReceiveType.bitcoin);

      expect(state.isPayjoinFlowOwningNavigation, isFalse);
    });

    test('false while the payjoin session is still idle (started): a plain '
        'send to this address, unrelated to payjoin, must still navigate '
        'via the generic listener', () {
      final state = ReceiveState(
        type: ReceiveType.bitcoin,
        payjoin: payjoinWith(status: PayjoinStatus.started),
      );

      expect(state.isPayjoinFlowOwningNavigation, isFalse);
    });

    test('true once a request has been received (requested/proposed/'
        'completed/expired) — the payjoin flow owns navigation from here', () {
      for (final status in [
        PayjoinStatus.requested,
        PayjoinStatus.proposed,
        PayjoinStatus.completed,
        PayjoinStatus.expired,
      ]) {
        final state = ReceiveState(
          type: ReceiveType.bitcoin,
          payjoin: payjoinWith(status: status),
        );

        expect(
          state.isPayjoinFlowOwningNavigation,
          isTrue,
          reason: 'status: $status',
        );
      }
    });
  });

  group('ReceiveState.isPayjoinLoading', () {
    test('false when payjoin is disabled globally, even with a locally-'
        'signing wallet and no payjoin session yet — otherwise this stays '
        'true forever (ReceiveBloc never creates a session while disabled) '
        'and paymentRequest (which waits on this) never resolves, so the QR '
        'code never renders', () {
      final state = ReceiveState(
        type: ReceiveType.bitcoin,
        wallet: localWallet(),
        payjoinMinAmountSat: 21000000, // maxMinAmountSat sentinel: disabled
      );

      expect(state.isPayjoinGloballyEnabled, isFalse);
      expect(state.isPayjoinLoading, isFalse);
    });

    test('true while payjoin is enabled globally and a session has not been '
        'created yet — the QR code legitimately waits for it', () {
      final state = ReceiveState(
        type: ReceiveType.bitcoin,
        wallet: localWallet(),
        payjoinMinAmountSat: 10000, // below the sentinel: enabled
      );

      expect(state.isPayjoinGloballyEnabled, isTrue);
      expect(state.isPayjoinLoading, isTrue);
    });

    test(
      'false once the settings fetch has not resolved yet (payjoinMinAmountSat '
      'null) — fail-closed: not "still loading a payjoin", since none will '
      'ever be created until isPayjoinGloballyEnabled resolves true',
      () {
        final state = ReceiveState(
          type: ReceiveType.bitcoin,
          wallet: localWallet(),
        );

        expect(state.payjoinMinAmountSat, isNull);
        expect(state.isPayjoinGloballyEnabled, isFalse);
        expect(state.isPayjoinLoading, isFalse);
      },
    );

    test('false once a payjoin session exists', () {
      final state = ReceiveState(
        type: ReceiveType.bitcoin,
        wallet: localWallet(),
        payjoinMinAmountSat: 10000,
        payjoin: payjoinWith(status: PayjoinStatus.requested),
      );

      expect(state.isPayjoinLoading, isFalse);
    });
  });
}
