import 'package:bull_exchange/src/buy/domain/buy_flow.dart';
import 'package:bull_exchange/src/buy/domain/buy_listed_wallets.dart';
import 'package:bull_exchange/src/exchange_payout_wallets.dart';
import 'package:exchange/steps.dart';
import 'package:primitives/primitives.dart';

/// Reads a receive address (without advancing the index) from the picked
/// app wallet, only one the flow listed.
class GetBuyReceiveAddressUsecase {
  final ExchangePayoutWallets _payouts;
  final BuyListedWallets _listed;

  const GetBuyReceiveAddressUsecase(this._payouts, this._listed);

  Future<Result<Destination, Failure>> execute(
    DestinationOptionAppWallet option,
  ) async {
    final wallet = _listed[option.walletId];
    final address = wallet == null
        ? null
        : await _payouts.receive(wallet, advance: false);
    return address == null
        ? const Err(BuyReceiveAddressUnavailable())
        : Ok(DestinationAppWallet(option.walletId, option.rail, address));
  }
}
