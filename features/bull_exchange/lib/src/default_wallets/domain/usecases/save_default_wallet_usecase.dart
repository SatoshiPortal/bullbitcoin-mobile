import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Saves [address] as the session account's default wallet of a network,
/// through the account's write gate. With [existingRecipientId] it updates
/// that recipient instead of creating one. Never sent for a session that is
/// no longer the current one.
class SaveDefaultWalletUsecase {
  final Exchange _exchange;

  const SaveDefaultWalletUsecase(this._exchange);

  Future<Result<DefaultWallet, ExchangeGatedWriteFailure>> execute(
    ExchangeSession session, {
    required BtcNetwork network,
    required String address,
    String? existingRecipientId,
  }) => _exchange.saveSessionDefaultWallet(
    session,
    walletType: network,
    address: address,
    existingRecipientId: existingRecipientId,
  );
}
