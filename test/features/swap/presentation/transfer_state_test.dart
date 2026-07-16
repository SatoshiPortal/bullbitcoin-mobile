import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _LiquidWallet extends Fake implements Wallet {
  @override
  bool get isLiquid => true;
}

void main() {
  group('TransferState input currencies', () {
    test('exposes bitcoin units before available fiat currencies', () {
      const state = TransferState(fiatCurrencyCodes: ['CAD', 'USD']);

      expect(state.inputAmountCurrencyCodes, ['BTC', 'sats', 'CAD', 'USD']);
    });

    test('converts sats input to canonical satoshis', () {
      const state = TransferState(
        inputAmountCurrencyCode: 'sats',
        amount: '1234',
      );

      expect(state.inputAmountSat, 1234);
    });

    test('converts BTC input to canonical satoshis', () {
      const state = TransferState(
        inputAmountCurrencyCode: 'BTC',
        amount: '0.00001234',
      );

      expect(state.inputAmountSat, 1234);
    });

    test('converts fiat input using the selected exchange rate', () {
      const state = TransferState(
        inputAmountCurrencyCode: 'CAD',
        amount: '50',
        exchangeRate: 100000,
      );

      expect(state.inputAmountSat, 50000);
    });

    test('formats Liquid bitcoin unit without changing picker value', () {
      final state = TransferState(
        inputAmountCurrencyCode: BitcoinUnit.btc.code,
        fromWallet: _LiquidWallet(),
      );

      expect(state.inputAmountCurrencyCode, 'BTC');
      expect(state.displayInputAmountCurrencyCode, 'L-BTC');
    });

    test(
      'Max preserves the exact canonical amount for rounded fiat display',
      () {
        const state = TransferState(
          inputAmountCurrencyCode: 'CAD',
          exchangeRate: 100000,
          maxAmountSat: 12345,
          amount: '12.34',
          exactInputAmountSat: 12345,
          useMaxAmount: true,
        );

        expect(state.maxAmountInput, '12.34');
        expect(state.inputAmountSat, 12345);
        expect(state.isMaxSelected, isTrue);
      },
    );

    test('exact source amount survives rounded fiat presentation', () {
      const state = TransferState(
        inputAmountCurrencyCode: 'CAD',
        exchangeRate: 100000,
        amount: '12.34',
        exactInputAmountSat: 12345,
      );

      expect(state.inputAmountSat, 12345);
    });
  });
}
