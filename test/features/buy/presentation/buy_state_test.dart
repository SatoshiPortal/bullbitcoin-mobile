import 'package:bull_exchange/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBuyOrder extends Mock implements BuyOrder {}

UserSummary _userSummary({required bool payjoinReceiveEnabled}) => UserSummary(
  userNumber: 1,
  groups: const [],
  profile: const UserProfile(firstName: 'Test', lastName: 'User'),
  email: 'test@example.com',
  balances: const [],
  dca: const UserDca(isActive: false),
  autoBuy: const UserAutoBuy(
    isActive: false,
    addresses: UserAutoBuyAddresses(),
  ),
  payjoinReceiveEnabled: payjoinReceiveEnabled,
);

void main() {
  late UserSummary userSummary;
  late WalletRegistration bitcoinWallet;
  late WalletRegistration liquidWallet;

  setUp(() {
    userSummary = _userSummary(payjoinReceiveEnabled: true);
    bitcoinWallet = walletRegistrationForTesting(
      id: 'bitcoin',
      network: BitcoinNetwork.mainnet,
      signer: WalletSigner.local,
    );
    liquidWallet = walletRegistrationForTesting(
      id: 'liquid',
      network: LiquidNetwork.mainnet,
      signer: WalletSigner.local,
    );
  });

  group('BuyState Payjoin choice', () {
    test('keeps Payjoin enabled below 50000 sats', () {
      final state = BuyState(
        userSummary: userSummary,
        selectedWallet: bitcoinWallet,
        payjoinGloballyEnabled: true,
        isFiatCurrencyInput: false,
        bitcoinUnit: BitcoinUnit.sats,
        amountInput: '10000',
      );
      expect(state.shouldUsePayjoin, isTrue);
      expect(state.copyWith(isPayjoinEnabled: false).shouldUsePayjoin, isFalse);
    });

    test('offers Payjoin only with both gates and a local Bitcoin wallet', () {
      final state = BuyState(
        userSummary: userSummary,
        selectedWallet: bitcoinWallet,
        payjoinGloballyEnabled: true,
      );

      expect(state.canOfferPayjoin, isTrue);
      expect(
        state.copyWith(payjoinGloballyEnabled: false).canOfferPayjoin,
        isFalse,
      );

      expect(
        state
            .copyWith(userSummary: _userSummary(payjoinReceiveEnabled: false))
            .canOfferPayjoin,
        isFalse,
      );

      expect(
        state.copyWith(selectedWallet: liquidWallet).canOfferPayjoin,
        isFalse,
      );
      final watchOnly = walletRegistrationForTesting(
        id: 'watch-only',
        network: BitcoinNetwork.mainnet,
      );
      expect(
        state.copyWith(selectedWallet: watchOnly).canOfferPayjoin,
        isFalse,
      );
      expect(state.copyWith(selectedWallet: null).canOfferPayjoin, isFalse);
    });

    test('uses Payjoin only when the pre-order toggle remains enabled', () {
      final state = BuyState(
        userSummary: userSummary,
        selectedWallet: bitcoinWallet,
        payjoinGloballyEnabled: true,
        isPayjoinEnabled: true,
        isFiatCurrencyInput: false,
        bitcoinUnit: BitcoinUnit.sats,
        amountInput: '100001',
      );

      expect(state.shouldUsePayjoin, isTrue);
      expect(state.copyWith(isPayjoinEnabled: false).shouldUsePayjoin, isFalse);
      expect(state.copyWith(amountInput: '').shouldUsePayjoin, isFalse);
    });
  });

  group('BuyState failure slots', () {
    const failure = BuyUnexpectedFailure('raw reason');

    test('confirmation can show a creation failure before an order exists', () {
      const beforeOrder = BuyState(failure: failure);
      expect(beforeOrder.inputFailure, failure);
      expect(beforeOrder.confirmFailure, failure);

      final withOrder = beforeOrder.copyWith(buyOrder: _MockBuyOrder());
      expect(withOrder.inputFailure, isNull);
      expect(withOrder.confirmFailure, failure);
    });

    test('the accelerate slot does not wait for an order to be loaded', () {
      // The accelerate routes each build their own bloc, so the entry refresh,
      // the fee read and the rate read all fail while buyOrder is still null.
      // Gating this slot on the order made those failures render nowhere.
      const beforeOrder = BuyState(failure: failure);
      expect(beforeOrder.accelerateFailure, failure);
      expect(
        beforeOrder.copyWith(buyOrder: _MockBuyOrder()).accelerateFailure,
        failure,
      );
    });

    test('every slot is empty when nothing failed', () {
      const state = BuyState();
      expect(state.inputFailure, isNull);
      expect(state.confirmFailure, isNull);
      expect(state.accelerateFailure, isNull);
    });
  });
}
