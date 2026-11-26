import 'package:bull_exchange/src/buy/domain/buy_flow.dart';
import 'package:bull_exchange/src/buy/domain/buy_listed_wallets.dart';
import 'package:bull_exchange/src/buy/domain/usecases/get_buy_receive_address_usecase.dart';
import 'package:bull_exchange/src/exchange_payout_wallets.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/testing.dart';

import '../../buy_test_ports.dart';

void main() {
  test('a wallet the flow did not list gives no address and is never '
      'read', () async {
    final inventory = BuyTestInventory(const {});
    final answer = await GetBuyReceiveAddressUsecase(
      ExchangePayoutWallets(inventory, BuyTestNative()),
      BuyListedWallets(),
    ).execute(const DestinationOptionAppWallet('w-btc', BtcNetwork.bitcoin));
    expect(
      answer,
      isA<Err<Destination, Failure>>().having(
        (e) => e.failure,
        'failure',
        isA<BuyReceiveAddressUnavailable>(),
      ),
    );
    expect(inventory.reads, isEmpty);
  });

  test('a listed wallet is asked; one no longer visible gives no '
      'address', () async {
    final inventory = BuyTestInventory(const {});
    final listed = BuyListedWallets()
      ..add(
        walletRegistrationForTesting(
          id: 'w-btc',
          network: BitcoinNetwork.mainnet,
        ),
      );
    final answer = await GetBuyReceiveAddressUsecase(
      ExchangePayoutWallets(inventory, BuyTestNative()),
      listed,
    ).execute(const DestinationOptionAppWallet('w-btc', BtcNetwork.bitcoin));
    expect(answer, isA<Err<Destination, Failure>>());
    expect(inventory.reads, ['w-btc']);
  });
}
