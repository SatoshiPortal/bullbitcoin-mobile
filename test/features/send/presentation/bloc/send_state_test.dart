import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
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

void main() {
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

  group('SendState.walletHasBalance validates against spendable, not total', () {
    SendState withAmount(int sats, {required int balance, required int frozen}) {
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
  });
}
