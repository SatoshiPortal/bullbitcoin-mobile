import 'package:exchange/exchange.dart';

/// Reads the default wallets of [ExchangeSession]'s account. A read for a
/// session that is no longer the current one is never sent: it answers
/// [ReadSessionRejected].
class GetDefaultWalletsUsecase {
  final Exchange _exchange;

  const GetDefaultWalletsUsecase(this._exchange);

  Future<ExchangeRead<DefaultWallets>> execute(ExchangeSession session) =>
      _exchange.readDefaultWallets(session);
}
