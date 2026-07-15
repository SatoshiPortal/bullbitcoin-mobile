import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../coins/wallet_utxo_fixture.dart';

/// Stubs only [Wallet.balanceSat]/[Wallet.id] — all [SendState] spendable math
/// reads from the utxo list plus the wallet balance, so nothing else is needed.
class _FakeWallet extends Fake implements Wallet {
  _FakeWallet(this._balanceSat);

  final int _balanceSat;

  @override
  String get id => 'w1';

  @override
  BigInt get balanceSat => BigInt.from(_balanceSat);
}

/// Tests for [SendState.absoluteFees] — the getter that decides which number
/// the user sees as their transaction fee.
///
/// The getter has three branches: no wallet → null; Liquid → the PSET-derived
/// `liquidAbsoluteFees`; Bitcoin → the PSBT-derived `bitcoinAbsoluteFeesSat`.
/// There is NO `rate × vsize` prediction fallback — when no PSBT exists the
/// getter returns null and the UI renders a shimmer placeholder. See
/// [issue #2133](https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2133)
/// and the on-chain reproducers `f0b40a72…` (paid 16 sat, predicted 14) and
/// `b734968d…` (paid 30 sat, predicted 28) — divergences that justified
/// removing the prediction path entirely.
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

  group('SendState.absoluteFees — Bitcoin, no PSBT means no number', () {
    // Architectural invariant from #2133: the displayed fee is the PSBT's
    // fee or nothing. We do NOT compute `rate × vsize` ourselves anywhere
    // — BDK's ceil + sub-dust change absorption makes that math diverge
    // by 1–3 sats at sub-1 sat/vByte rates (see reproducers in the file
    // header). The UI must render a shimmer placeholder via
    // `formattedAbsoluteFees == '…'` instead of a wrong number.

    test('returns null when no PSBT has been built yet', () {
      final state = SendState(
        selectedWallet: bitcoinWallet(),
        selectedFeeOption: FeeSelection.custom,
        customFee: NetworkFee.relativeFromSatPerVbyte(0.1),
        bitcoinTxSize: 140,
      );
      expect(state.bitcoinAbsoluteFeesSat, isNull);
      expect(state.absoluteFees, isNull);
    });

    test('returns null even when a preset rate and txSize are loaded', () {
      final feeOptions = FeeOptions(
        fastest: NetworkFee.relativeFromSatPerVbyte(10),
        economic: NetworkFee.relativeFromSatPerVbyte(5),
        slow: NetworkFee.relativeFromSatPerVbyte(2),
        minRelay: NetworkFee.relativeFromSatPerVbyte(0.1),
      );
      final state = SendState(
        selectedWallet: bitcoinWallet(),
        bitcoinFeesList: feeOptions,
        bitcoinTxSize: 140,
      );
      // Default selectedFeeOption is `fastest`. Old behaviour would have
      // returned 10 × 140 = 1400. New behaviour: no PSBT → null, no
      // arithmetic anywhere.
      expect(state.absoluteFees, isNull);
    });

    test('formattedAbsoluteFees renders the ellipsis placeholder', () {
      // UI contract: the send screen renders this string verbatim. A
      // brief '…' is honest about "not yet known" and works with the
      // shimmer placeholders elsewhere in the modal flow.
      final state = SendState(
        selectedWallet: bitcoinWallet(),
        bitcoinUnit: BitcoinUnit.sats,
        selectedFeeOption: FeeSelection.custom,
        customFee: NetworkFee.relativeFromSatPerVbyte(10),
      );
      expect(state.formattedAbsoluteFees, '…');
    });
  });

  group('SendState.copyWith — explicit null clears bitcoinAbsoluteFeesSat', () {
    // Load-bearing: send_cubit.dart:1173 clears bitcoinAbsoluteFeesSat to
    // null at the start of every rebuild so the UI doesn't pair a stale
    // real fee with newly-changed inputs. If freezed ever changed
    // copyWith's null-handling semantics, that clear would silently no-op
    // and the bug we're fixing would resurface.
    test('copyWith(bitcoinAbsoluteFeesSat: null) actually nulls the field', () {
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
    });

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
    // The "displayed fee is realistic" invariant is now single-pronged:
    // the displayed value IS the PSBT's fee, or it is nothing. Removing
    // the prediction fallback eliminates the divergence class that put
    // tx f0b40a72… (predicted 14, paid 16) and tx b734968d… (predicted
    // 28, paid 30) on chain at the wrong number — and the more recent
    // tx f98dde7c… (displayed 30, broadcast 23) caused by BDK's
    // non-deterministic coin selection between preview and commit.
    //
    // The reproducers below set `bitcoinAbsoluteFeesSat` directly to
    // the on-chain value; the assertion is that `absoluteFees` echoes
    // it without any local math.

    test('at 0.1 sat/vByte the displayed fee is the on-chain fee verbatim '
        '(tx f0b40a72…)', () {
      final state = SendState(
        selectedWallet: bitcoinWallet(),
        selectedFeeOption: FeeSelection.custom,
        customFee: NetworkFee.relativeFromSatPerVbyte(0.1),
        bitcoinTxSize: 140,
        bitcoinAbsoluteFeesSat: 16,
      );
      expect(state.absoluteFees, 16);
    });

    test('at 0.2 sat/vByte the displayed fee is the on-chain fee verbatim '
        '(tx b734968d…)', () {
      final state = SendState(
        selectedWallet: bitcoinWallet(),
        selectedFeeOption: FeeSelection.custom,
        customFee: NetworkFee.relativeFromSatPerVbyte(0.2),
        bitcoinTxSize: 140,
        bitcoinAbsoluteFeesSat: 30,
      );
      expect(state.absoluteFees, 30);
    });

    test('at normal rates the displayed fee is the PSBT fee verbatim', () {
      // Reality at on-chain vsize 140 with BDK ceil for a 10 sat/vB
      // request comes out at 1400. We assert verbatim echo, not
      // arithmetic — the test guards against any reintroduction of a
      // `rate × vsize` shortcut.
      final state = SendState(
        selectedWallet: bitcoinWallet(),
        selectedFeeOption: FeeSelection.custom,
        customFee: NetworkFee.relativeFromSatPerVbyte(10),
        bitcoinTxSize: 140,
        bitcoinAbsoluteFeesSat: 1400,
      );
      expect(state.absoluteFees, 1400);
    });
  });

  // D7: a frozen coin is never spendable. The amount screen, the MAX button and
  // the chain-swap MAX all route through SendState.spendableBalanceSat, so these
  // getters are the unit under test for the "frozen reduces spendable" rule.
  group('SendState frozen/spendable balance (D7)', () {
    test('frozenBalanceSat sums only frozen utxos', () {
      final state = SendState(
        selectedWallet: _FakeWallet(300000),
        utxos: [
          walletUtxoFixture(sats: 100000, vout: 0),
          walletUtxoFixture(sats: 50000, vout: 1, isFrozen: true),
          walletUtxoFixture(sats: 150000, vout: 2, isFrozen: true),
        ],
      );

      expect(state.frozenBalanceSat, 200000);
    });

    test('spendableBalanceSat = wallet balance - frozen total', () {
      final state = SendState(
        selectedWallet: _FakeWallet(300000),
        utxos: [
          walletUtxoFixture(sats: 100000, vout: 0),
          walletUtxoFixture(sats: 50000, vout: 1, isFrozen: true),
        ],
      );

      expect(state.spendableBalanceSat, 250000);
    });

    test('falls back to the full balance before utxos have loaded', () {
      final state = SendState(selectedWallet: _FakeWallet(300000));

      expect(state.frozenBalanceSat, 0);
      expect(state.spendableBalanceSat, 300000);
    });

    test('is 0 when no wallet is selected', () {
      const state = SendState();

      expect(state.spendableBalanceSat, 0);
    });
  });

  group('SendState.willAttemptPayjoin', () {
    Bip21PaymentRequest bip21WithPj({String pj = 'https://payjo.in'}) =>
        PaymentRequest.bip21(
              network: Network.bitcoinMainnet,
              uri: 'bitcoin:bc1qtest?pj=$pj',
              address: 'bc1qtest',
              pj: pj,
            )
            as Bip21PaymentRequest;

    test('false when payjoin is disabled globally, even with a pj= URI', () {
      final state = SendState(
        paymentRequest: bip21WithPj(),
        payjoinGloballyEnabled: false,
      );
      expect(state.willAttemptPayjoin, isFalse);
    });

    test(
      'false for a self-transfer, even with a pj= URI and the setting on',
      () {
        final state = SendState(
          paymentRequest: bip21WithPj(),
          payjoinGloballyEnabled: true,
          isToSelf: true,
        );
        expect(state.willAttemptPayjoin, isFalse);
      },
    );

    test('false for a BIP21 URI without a pj= parameter', () {
      final state = SendState(
        paymentRequest: bip21WithPj(pj: ''),
        payjoinGloballyEnabled: true,
      );
      expect(state.willAttemptPayjoin, isFalse);
    });

    test('false for a non-BIP21 payment request', () {
      final state = SendState(
        paymentRequest: const PaymentRequest.bitcoin(
          address: 'bc1qtest',
          isTestnet: false,
        ),
        payjoinGloballyEnabled: true,
      );
      expect(state.willAttemptPayjoin, isFalse);
    });

    test('true when enabled globally, not a self-transfer, a locally-signing '
        'wallet, and the BIP21 URI carries a pj= parameter', () {
      final state = SendState(
        selectedWallet: bitcoinWallet(),
        paymentRequest: bip21WithPj(),
        payjoinGloballyEnabled: true,
        isToSelf: false,
      );
      expect(state.willAttemptPayjoin, isTrue);
    });

    test('false when no wallet is selected yet, even if every other condition '
        'is met — fail-closed default', () {
      final state = SendState(
        paymentRequest: bip21WithPj(),
        payjoinGloballyEnabled: true,
        isToSelf: false,
      );
      expect(state.willAttemptPayjoin, isFalse);
    });

    test('false for a hardware/remote-signer wallet (Ledger/BitBox): the '
        "confirm screen's device-specific sign button never reaches "
        "signTransaction's payjoin branch, so the indicator must not promise "
        'one', () {
      final state = SendState(
        selectedWallet: Wallet(
          origin: 'test-hw-origin',
          network: Network.bitcoinMainnet,
          xpubFingerprint: '00000000',
          scriptType: ScriptType.bip84,
          xpub: '',
          externalPublicDescriptor: '',
          internalPublicDescriptor: '',
          signer: SignerEntity.remote,
          signerDevice: SignerDeviceEntity.ledgerNanoX,
          balanceSat: BigInt.from(100000),
        ),
        paymentRequest: bip21WithPj(),
        payjoinGloballyEnabled: true,
        isToSelf: false,
      );
      expect(state.willAttemptPayjoin, isFalse);
    });
  });

  group(
    'SendState.walletHasBalance validates against spendable, not total',
    () {
      SendState withAmount(
        int sats, {
        required int balance,
        required int frozen,
      }) {
        return SendState(
          selectedWallet: _FakeWallet(balance),
          inputAmountCurrencyCode: BitcoinUnit.sats.code,
          amount: '$sats',
          utxos: frozen > 0
              ? [walletUtxoFixture(sats: frozen, vout: 9, isFrozen: true)]
              : const [],
        );
      }

      test('amount within spendable → true', () {
        final state = withAmount(40000, balance: 100000, frozen: 50000);

        expect(state.walletHasBalance, isTrue);
      });

      test('amount above spendable but below total → false (the D7 fix)', () {
        // Total balance (100k) would have passed the old raw-balance check, but
        // only 50k is actually spendable with 50k frozen.
        final state = withAmount(70000, balance: 100000, frozen: 50000);

        expect(state.walletHasBalance, isFalse);
      });

      test('false when no wallet is selected', () {
        final state = SendState(
          inputAmountCurrencyCode: BitcoinUnit.sats.code,
          amount: '1000',
        );

        expect(state.walletHasBalance, isFalse);
      });

      test('false for a zero amount', () {
        final state = withAmount(0, balance: 100000, frozen: 0);

        expect(state.walletHasBalance, isFalse);
      });
    },
  );
}
