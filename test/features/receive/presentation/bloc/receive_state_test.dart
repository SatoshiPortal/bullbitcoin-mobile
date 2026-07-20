import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the payjoin gating on [ReceiveState.isPayjoinLoading] and its
/// downstream effect on [ReceiveState.paymentRequest]: with payjoin disabled
/// globally, the bloc never creates a session and never sets an exception,
/// so without the [ReceiveState.payjoinGloballyEnabled] gate the QR data
/// would wait for a payjoin forever and never render — and payjoin is
/// disabled by default, so that would be every fresh install's receive
/// screen.
void main() {
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

  WalletAddress address() => WalletAddress(
    walletId: 'w1',
    index: 0,
    address: 'bc1qtestaddress',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  ReceiveState buildState({required bool? payjoinGloballyEnabled}) =>
      ReceiveState(
        type: ReceiveType.bitcoin,
        wallet: localWallet(),
        bitcoinAddress: address(),
        payjoinGloballyEnabled: payjoinGloballyEnabled,
      );

  group('ReceiveState.isPayjoinLoading payjoin-disabled gate', () {
    test('not loading when payjoin is globally disabled — no session will ever '
        'be created, so nothing must wait for one', () {
      final state = buildState(payjoinGloballyEnabled: false);

      expect(state.isPayjoinLoading, isFalse);
    });

    test('still loading while the setting has not been read yet (null): the QR '
        'must not flash an address-only URI and then swap to a pj= BIP21', () {
      final state = buildState(payjoinGloballyEnabled: null);

      expect(state.isPayjoinLoading, isTrue);
    });

    test('loading when enabled and no session or exception exists yet', () {
      final state = buildState(payjoinGloballyEnabled: true);

      expect(state.isPayjoinLoading, isTrue);
    });
  });

  group('ReceiveState.paymentRequest with payjoin disabled', () {
    test('resolves to the plain address instead of waiting forever', () {
      final state = buildState(payjoinGloballyEnabled: false);

      expect(state.paymentRequest, 'bc1qtestaddress');
      expect(state.qrData, 'bc1qtestaddress');
    });

    test('stays empty (still loading) while the setting is unknown', () {
      final state = buildState(payjoinGloballyEnabled: null);

      expect(state.paymentRequest, isEmpty);
    });
  });

  PayjoinReceiver payjoinWith({
    required PayjoinStatus status,
    int? amountSat,
  }) =>
      Payjoin.receiver(
            status: status,
            id: 'pj1',
            isTestnet: true,
            walletId: 'w1',
            pjUri: 'bitcoin:tb1qtest?pj=https://payjo.in',
            createdAt: DateTime(2026),
            expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
            amountSat: amountSat,
          )
          as PayjoinReceiver;

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
        'completed/aborted/expired) — the payjoin flow owns navigation '
        'from here', () {
      for (final status in [
        PayjoinStatus.requested,
        PayjoinStatus.proposed,
        PayjoinStatus.completed,
        PayjoinStatus.aborted,
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

  group('ReceiveState.isPayjoinBelowMinimum', () {
    test('true when the session aborted below the configured minimum', () {
      final state = ReceiveState(
        type: ReceiveType.bitcoin,
        payjoin: payjoinWith(status: PayjoinStatus.aborted, amountSat: 5000),
        payjoinMinAmountSat: 10000,
      );

      expect(state.isPayjoinBelowMinimum, isTrue);
    });

    test('false when the aborted amount is exactly the minimum', () {
      final state = ReceiveState(
        type: ReceiveType.bitcoin,
        payjoin: payjoinWith(status: PayjoinStatus.aborted, amountSat: 10000),
        payjoinMinAmountSat: 10000,
      );

      expect(state.isPayjoinBelowMinimum, isFalse);
    });

    test('false when below the minimum but not aborted (still requested)', () {
      final state = ReceiveState(
        type: ReceiveType.bitcoin,
        payjoin: payjoinWith(status: PayjoinStatus.requested, amountSat: 5000),
        payjoinMinAmountSat: 10000,
      );

      expect(state.isPayjoinBelowMinimum, isFalse);
    });

    test('false when the minimum is unknown (settings not read yet)', () {
      final state = ReceiveState(
        type: ReceiveType.bitcoin,
        payjoin: payjoinWith(status: PayjoinStatus.aborted, amountSat: 5000),
        payjoinMinAmountSat: null,
      );

      expect(state.isPayjoinBelowMinimum, isFalse);
    });
  });
}
