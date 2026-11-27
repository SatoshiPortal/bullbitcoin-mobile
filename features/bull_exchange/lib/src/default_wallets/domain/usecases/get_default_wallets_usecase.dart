import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Reads the default wallets of [ExchangeSession]'s account. A read for a
/// session that is no longer the current one is never sent: it answers
/// [ExchangeSessionRejectedFailure].
class GetDefaultWalletsUsecase {
  final Exchange _exchange;

  const GetDefaultWalletsUsecase(this._exchange);

  Future<Result<DefaultWallets, ExchangeReadFailure>> execute(
    ExchangeSession session,
  ) => _exchange.readDefaultWallets(session);
}
