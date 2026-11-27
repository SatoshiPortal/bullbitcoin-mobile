import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Unsets the session account's default wallet of a network (the recipient
/// stays), through the account's write gate. Never sent for a session that
/// is no longer the current one.
class UnsetDefaultWalletUsecase {
  final Exchange _exchange;

  const UnsetDefaultWalletUsecase(this._exchange);

  Future<Result<void, ExchangeGatedWriteFailure>> execute(
    ExchangeSession session, {
    required BtcNetwork network,
    required String recipientId,
    required String address,
  }) => _exchange.unsetSessionDefaultWallet(
    session,
    recipientId: recipientId,
    walletType: network,
    address: address,
  );
}
