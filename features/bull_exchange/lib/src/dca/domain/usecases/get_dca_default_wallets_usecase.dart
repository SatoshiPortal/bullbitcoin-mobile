import 'package:bull_exchange/src/dca/domain/dca_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The exchange default wallets (Bitcoin, Lightning, Liquid addresses saved on
/// the user's Bull Bitcoin account), the payout destinations a recurring buy
/// offers, like AutoBuy and limit orders.
class GetDcaDefaultWalletsUsecase {
  final Exchange _exchange;

  const GetDcaDefaultWalletsUsecase({required this._exchange});

  @useResult
  Future<Result<DefaultWallets, DcaFailure>> execute() async {
    switch (await _exchange.getDefaultWallets()) {
      case Ok(:final value):
        return Ok(value);
      case Err(:final failure):
        log.warning(
          'Failed to read the default wallets for a recurring buy: '
          '${failure.logMessage ?? failure.runtimeType}',
        );
        return const Err(DcaAccountUnavailableFailure('default wallets'));
    }
  }
}
