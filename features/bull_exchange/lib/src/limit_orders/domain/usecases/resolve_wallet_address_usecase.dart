import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_orders_failure.dart';
import 'package:meta/meta.dart';
import 'package:secrets/secrets.dart';

import '../../../exchange_payout_wallets.dart';

class ResolveWalletAddressUsecase {
  final ExchangePayoutWallets _payouts;

  const ResolveWalletAddressUsecase(this._payouts);

  @useResult
  Future<Result<String, LimitOrdersFailure>> execute(
    WalletRegistration wallet,
  ) async {
    final address = await _payouts.receive(wallet, advance: false);
    return switch (address) {
      final value? => Ok(value),
      null => const Err(
        LimitOrdersUnexpectedFailure('Receive address unavailable'),
      ),
    };
  }
}
