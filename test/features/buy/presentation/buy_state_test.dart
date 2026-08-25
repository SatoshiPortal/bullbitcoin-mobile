import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWallet extends Mock implements Wallet {}

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
  late Wallet bitcoinWallet;
  late Wallet liquidWallet;

  setUp(() {
    userSummary = _userSummary(payjoinReceiveEnabled: true);
    bitcoinWallet = _MockWallet();
    liquidWallet = _MockWallet();

    when(() => bitcoinWallet.network).thenReturn(Network.bitcoinMainnet);
    when(() => bitcoinWallet.isBitcoin).thenReturn(true);
    when(
      () => bitcoinWallet.isStandardLocalSingleSignatureWallet,
    ).thenReturn(true);
    when(() => liquidWallet.network).thenReturn(Network.liquidMainnet);
    when(() => liquidWallet.isBitcoin).thenReturn(false);
    when(
      () => liquidWallet.isStandardLocalSingleSignatureWallet,
    ).thenReturn(true);
  });

  group('BuyState Payjoin choice', () {
    test(
      'offers Payjoin only when both gates and a Bitcoin wallet are set',
      () {
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
        expect(state.copyWith(selectedWallet: null).canOfferPayjoin, isFalse);

        when(
          () => bitcoinWallet.isStandardLocalSingleSignatureWallet,
        ).thenReturn(false);
        expect(state.canOfferPayjoin, isFalse);
      },
    );

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

    test('the input and confirm slots split on whether an order exists', () {
      const beforeOrder = BuyState(failure: failure);
      expect(beforeOrder.inputFailure, failure);
      expect(beforeOrder.confirmFailure, isNull);

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
