import 'package:bull_exchange/src/exchange_payout_wallets.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_listed_wallets.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/get_limit_receive_address_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/testing.dart';

import '../../../buy/buy_test_ports.dart';

Matcher _refused(String why) => isA<Err<Destination, Failure>>().having(
  (e) => e.failure,
  'failure',
  isA<ExchangeDestinationUnavailableFailure>().having(
    (f) => f.logMessage,
    'why',
    why,
  ),
);

void main() {
  const option = DestinationOptionAppWallet('w-btc', BtcNetwork.bitcoin);

  test('a wallet the flow did not list gives no address and is never '
      'read', () async {
    final inventory = BuyTestInventory(const {});
    final answer = await GetLimitReceiveAddressUsecase(
      ExchangePayoutWallets(inventory, BuyTestNative()),
      LimitListedWallets(),
    ).execute(option);
    expect(answer, _refused('wallet no longer listed'));
    expect(inventory.reads, isEmpty);
  });

  test('a listed wallet is asked; one no longer visible gives no '
      'address', () async {
    final inventory = BuyTestInventory(const {});
    final listed = LimitListedWallets()
      ..replaceAll([
        walletRegistrationForTesting(
          id: 'w-btc',
          network: BitcoinNetwork.mainnet,
        ),
      ]);
    final answer = await GetLimitReceiveAddressUsecase(
      ExchangePayoutWallets(inventory, BuyTestNative()),
      listed,
    ).execute(option);
    expect(answer, _refused('receive address unavailable'));
    expect(inventory.reads, ['w-btc']);
  });
}
