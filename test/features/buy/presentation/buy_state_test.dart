import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWallet extends Mock implements Wallet {}

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
    when(() => liquidWallet.network).thenReturn(Network.liquidMainnet);
  });

  group('BuyState Payjoin choice', () {
    test('offers Payjoin when the exchange supports it and a Bitcoin wallet is '
        'set', () {
      final state = BuyState(
        userSummary: userSummary,
        selectedWallet: bitcoinWallet,
      );

      expect(state.canOfferPayjoin, isTrue);

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
    });

    test('uses Payjoin only when the pre-order toggle remains enabled', () {
      final state = BuyState(
        userSummary: userSummary,
        selectedWallet: bitcoinWallet,
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
}
