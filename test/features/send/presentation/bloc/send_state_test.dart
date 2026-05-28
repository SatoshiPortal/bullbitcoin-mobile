import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for [SendState.absoluteFees] — the getter that decides which number
/// the user sees as their transaction fee.
///
/// The getter has three branches: no wallet → null; Liquid → the PSET-derived
/// `liquidAbsoluteFees`; Bitcoin → the PSBT-derived `bitcoinAbsoluteFeesSat`
/// when present, otherwise a `rate × txSize` prediction.
///
/// This file's job is to lock in the "realistic" invariant: when a PSBT
/// exists the displayed fee MUST be the one BDK actually produced, not a
/// prediction that diverges by 1-3 sats at sub-1 sat/vByte rates. See
/// [issue #2133](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2133)
/// and the on-chain reproducers `f0b40a72…` (paid 16 sat, predicted 14) and
/// `b734968d…` (paid 30 sat, predicted 28).
void main() {
  Wallet bitcoinWallet() => Wallet(
    origin: 'test-btc-origin',
    network: Network.bitcoinMainnet,
    xpubFingerprint: '00000000',
    scriptType: ScriptType.bip84,
    xpub: '',
    externalPublicDescriptor: '',
    internalPublicDescriptor: '',
    signer: SignerEntity.local,
    signerDevice: null,
    balanceSat: BigInt.from(100000),
  );

  Wallet liquidWallet() => Wallet(
    origin: 'test-lbtc-origin',
    network: Network.liquidMainnet,
    xpubFingerprint: '00000000',
    scriptType: ScriptType.bip84,
    xpub: '',
    externalPublicDescriptor: '',
    internalPublicDescriptor: '',
    signer: SignerEntity.local,
    signerDevice: null,
    balanceSat: BigInt.from(100000),
  );

  group('SendState.absoluteFees — no wallet', () {
    test('returns null when no wallet is selected', () {
      const state = SendState();
      expect(state.absoluteFees, isNull);
    });
  });

  group('SendState.absoluteFees — Liquid', () {
    test('returns liquidAbsoluteFees verbatim (already PSET-derived)', () {
      final state = SendState(
        selectedWallet: liquidWallet(),
        liquidAbsoluteFees: 1234,
      );
      expect(state.absoluteFees, 1234);
    });

    test('returns null when liquidAbsoluteFees not set', () {
      final state = SendState(selectedWallet: liquidWallet());
      expect(state.absoluteFees, isNull);
    });

    test('ignores bitcoinAbsoluteFeesSat for a Liquid wallet', () {
      // Cross-talk guard: a stray bitcoin fee in state must never leak into
      // the liquid display path.
      final state = SendState(
        selectedWallet: liquidWallet(),
        liquidAbsoluteFees: 100,
        bitcoinAbsoluteFeesSat: 9999,
      );
      expect(state.absoluteFees, 100);
    });
  });

  group('SendState.absoluteFees — Bitcoin, real fee takes priority', () {
    test('returns bitcoinAbsoluteFeesSat when set, ignoring prediction', () {
      // #2133 reproducer tx 1 (f0b40a72…): user picked 0.1 sat/vB, predicted
      // vsize 140 vB → naive prediction 14 sat. BDK actually broadcast 16
      // sat (ceil + sub-dust change absorption at weight 561). The
      // displayed fee MUST be 16, not 14.
      final state = SendState(
        selectedWallet: bitcoinWallet(),
        selectedFeeOption: FeeSelection.custom,
        customFee: NetworkFee.relativeFromSatPerVbyte(0.1),
        bitcoinTxSize: 140,
        bitcoinAbsoluteFeesSat: 16,
      );
      expect(state.absoluteFees, 16);
    });

    test('reproducer tx 2 (b734968d…): real 30 wins over predicted 28', () {
      final state = SendState(
        selectedWallet: bitcoinWallet(),
        selectedFeeOption: FeeSelection.custom,
        customFee: NetworkFee.relativeFromSatPerVbyte(0.2),
        bitcoinTxSize: 140,
        bitcoinAbsoluteFeesSat: 30,
      );
      expect(state.absoluteFees, 30);
    });

    test('ignores liquidAbsoluteFees on the Bitcoin path', () {
      // Cross-talk guard the other direction.
      final state = SendState(
        selectedWallet: bitcoinWallet(),
        bitcoinAbsoluteFeesSat: 100,
        liquidAbsoluteFees: 9999,
      );
      expect(state.absoluteFees, 100);
    });
  });

  group('SendState.absoluteFees — Bitcoin prediction fallback', () {
    test(
      'falls back to selectedFee.toAbsolute(bitcoinTxSize) when no PSBT yet',
      () {
        // Pre-PSBT window: no real fee is known. The getter must still
        // produce a number so the UI can show something. Prediction at
        // 0.1 sat/vB × 140 vB = 14 sat, as in tx 1's reproducer.
        final state = SendState(
          selectedWallet: bitcoinWallet(),
          selectedFeeOption: FeeSelection.custom,
          customFee: NetworkFee.relativeFromSatPerVbyte(0.1),
          bitcoinTxSize: 140,
        );
        expect(state.bitcoinAbsoluteFeesSat, isNull);
        expect(state.absoluteFees, 14);
      },
    );

    test('reflects the chosen preset, not just custom rates', () {
      final feeOptions = FeeOptions(
        fastest: NetworkFee.relativeFromSatPerVbyte(10),
        economic: NetworkFee.relativeFromSatPerVbyte(5),
        slow: NetworkFee.relativeFromSatPerVbyte(2),
      );
      final state = SendState(
        selectedWallet: bitcoinWallet(),
        bitcoinFeesList: feeOptions,
        bitcoinTxSize: 140,
      );
      // Default selectedFeeOption is `fastest`. 10 sat/vB × 140 vB = 1400.
      expect(state.absoluteFees, 1400);
    });

    test('returns null when neither real fee nor selectedFee is available', () {
      final state = SendState(
        selectedWallet: bitcoinWallet(),
        bitcoinTxSize: 140,
      );
      // selectedFeeOption defaults to FeeSelection.fastest, but with no
      // bitcoinFeesList loaded selectedFee resolves to null.
      expect(state.absoluteFees, isNull);
    });

    test('treats unknown bitcoinTxSize as 0 (rate × 0 = 0)', () {
      // Edge case: prediction with no size info collapses to 0. Acceptable
      // — the UI is in a transient pre-build state. Documenting current
      // behaviour so a future change is deliberate.
      final state = SendState(
        selectedWallet: bitcoinWallet(),
        selectedFeeOption: FeeSelection.custom,
        customFee: NetworkFee.relativeFromSatPerVbyte(10),
      );
      expect(state.absoluteFees, 0);
    });
  });

  group('SendState.copyWith — explicit null clears bitcoinAbsoluteFeesSat', () {
    // Load-bearing: send_cubit.dart:1173 clears bitcoinAbsoluteFeesSat to
    // null at the start of every rebuild so the UI doesn't pair a stale
    // real fee with newly-changed inputs. If freezed ever changed
    // copyWith's null-handling semantics, that clear would silently no-op
    // and the bug we're fixing would resurface.
    test(
      'copyWith(bitcoinAbsoluteFeesSat: null) actually nulls the field',
      () {
        final state = SendState(
          selectedWallet: bitcoinWallet(),
          bitcoinAbsoluteFeesSat: 42,
        );
        expect(state.bitcoinAbsoluteFeesSat, 42);

        final cleared = state.copyWith(bitcoinAbsoluteFeesSat: null);
        expect(cleared.bitcoinAbsoluteFeesSat, isNull);
        // Getter must fall back to the prediction, not silently retain 42.
        // No selectedFee here, so the prediction resolves to null.
        expect(cleared.absoluteFees, isNull);
      },
    );

    test('omitting bitcoinAbsoluteFeesSat from copyWith preserves it', () {
      // The other half of the contract: passing nothing keeps the value.
      final state = SendState(
        selectedWallet: bitcoinWallet(),
        bitcoinAbsoluteFeesSat: 42,
      );
      final unchanged = state.copyWith(buildingTransaction: true);
      expect(unchanged.bitcoinAbsoluteFeesSat, 42);
    });
  });

  group('SendState.absoluteFees — realism invariant', () {
    // The "displayed fee is realistic" invariant has two parts:
    //   (a) When a PSBT exists, the displayed value IS the PSBT's fee.
    //   (b) When no PSBT exists, the prediction must not overshoot the
    //       real BDK fee (since BDK applies ceil + sub-dust absorption,
    //       BDK ≥ prediction structurally). Underestimating by ≤3 sat at
    //       sub-1 sat/vByte is documented BDK behaviour; overestimating
    //       in the prediction would be a bug because it would make a
    //       valid send look insufficient against the balance.
    //
    // Part (a) is covered by the priority tests above. This group locks
    // in part (b) for the rates AGENTS.md / PR #2199 explicitly support.

    test(
      'prediction at 0.1 sat/vByte never exceeds the BDK-real fee '
      'observed on-chain (tx f0b40a72…)',
      () {
        final state = SendState(
          selectedWallet: bitcoinWallet(),
          selectedFeeOption: FeeSelection.custom,
          customFee: NetworkFee.relativeFromSatPerVbyte(0.1),
          bitcoinTxSize: 140, // pre-build txSize estimate
        );
        const observedOnChainFee = 16;
        expect(
          state.absoluteFees,
          lessThanOrEqualTo(observedOnChainFee),
          reason:
              'Prediction must be a lower bound on the real fee — a high '
              'prediction would surface false InsufficientBalance errors.',
        );
      },
    );

    test(
      'prediction at 0.2 sat/vByte never exceeds the BDK-real fee '
      'observed on-chain (tx b734968d…)',
      () {
        final state = SendState(
          selectedWallet: bitcoinWallet(),
          selectedFeeOption: FeeSelection.custom,
          customFee: NetworkFee.relativeFromSatPerVbyte(0.2),
          bitcoinTxSize: 140,
        );
        const observedOnChainFee = 30;
        expect(state.absoluteFees, lessThanOrEqualTo(observedOnChainFee));
      },
    );

    test(
      'at normal rates the prediction matches reality within ±1 sat per '
      'vbyte of txSize uncertainty',
      () {
        // Pick a normal rate (10 sat/vB). Predict at vsize 140. Reality
        // at on-chain vsize 140.25 with BDK ceil would be ceil(10*140.25)=
        // 1403 sat or 10*140=1400. Either way within ±3 sat.
        final state = SendState(
          selectedWallet: bitcoinWallet(),
          selectedFeeOption: FeeSelection.custom,
          customFee: NetworkFee.relativeFromSatPerVbyte(10),
          bitcoinTxSize: 140,
        );
        expect(state.absoluteFees, 1400);
        // The corresponding BDK ceil at weight 561 (vsize 140.25):
        // ceil(2500 sat/kwu × 561 / 1000) = ceil(1402.5) = 1403.
        // 1400 ≤ 1403, invariant holds.
      },
    );
  });
}
