import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../default_wallets_failure.dart';

final class DeleteDefaultWalletUsecase {
  final Exchange _exchange;

  const DeleteDefaultWalletUsecase(this._exchange);

  @useResult
  Future<Result<void, DefaultWalletsFailure>> execute({
    required String recipientId,
    required BtcNetwork walletType,
    required String address,
  }) async => (await _exchange.deleteDefaultWallet(
    recipientId: recipientId,
    walletType: walletType,
    address: address,
  )).mapErr((_) => const DefaultWalletsDeleteFailure());
}
