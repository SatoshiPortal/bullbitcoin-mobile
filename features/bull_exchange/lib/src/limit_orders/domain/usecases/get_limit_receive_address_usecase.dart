import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/exchange_payout_wallets.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_listed_wallets.dart';
import 'package:exchange/steps.dart';
import 'package:primitives/primitives.dart';

/// Reads a receive address (without advancing the index) from the picked
/// app wallet, only one the latest context load listed.
class GetLimitReceiveAddressUsecase {
  final ExchangePayoutWallets _payouts;
  final LimitListedWallets _listed;

  const GetLimitReceiveAddressUsecase(this._payouts, this._listed);

  Future<Result<Destination, ExchangeFailure>> execute(
    DestinationOptionAppWallet option,
  ) async {
    final wallet = _listed[option.walletId];
    if (wallet == null) {
      return const Err(
        ExchangeDestinationUnavailableFailure('wallet no longer listed'),
      );
    }
    return switch (await _payouts.receive(wallet, advance: false)) {
      final address? => Ok(
        DestinationAppWallet(option.walletId, option.rail, address),
      ),
      null => const Err(
        ExchangeDestinationUnavailableFailure('receive address unavailable'),
      ),
    };
  }
}
