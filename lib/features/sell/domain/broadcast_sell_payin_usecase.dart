import 'package:bb_mobile/features/send/public/broadcast_failure.dart';
import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/send/public/send_facade.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' hide Network;

class BroadcastSellPayinUsecase {
  final WalletFacade _wallet;
  final SendFacade _send;

  const BroadcastSellPayinUsecase({required this._wallet, required this._send});

  @useResult
  Future<Result<String, SellFailure>> bitcoin(
    String transaction, {
    required String walletId,
    required bool isPsbt,
    required Network network,
  }) async {
    try {
      final txid = await _send.bitcoin(
        transaction,
        isPsbt: isPsbt,
        walletId: walletId,
        network: network,
      );
      _wallet.pollWallet(walletId, isActive: () => true).ignore();
      return Ok(txid);
    } on WalletSpendBlockedException catch (e) {
      return Err(
        SellSpendBlockedFailure(busy: e.status == BitcoinSpendStatus.busy),
      );
    } on Exception catch (e) {
      return Err(_broadcastFailure(e, 'bitcoin'));
    }
  }

  @useResult
  Future<Result<String, SellFailure>> liquid(
    String signedPset, {
    required String walletId,
  }) async {
    try {
      final txid = await _send.liquid(signedPset);
      _wallet.pollWallet(walletId, isActive: () => true).ignore();
      return Ok(txid);
    } on Exception catch (e) {
      return Err(_broadcastFailure(e, 'liquid'));
    }
  }

  SellFailure _broadcastFailure(Exception error, String chain) {
    const code = 'sell_payin_broadcast_failed';
    final category = BroadcastFailureCategory.of(error);
    final message = '$code chain=$chain category=${category.name}';
    if (error is BroadcastTransactionException) {
      log.warning(message);
    } else {
      log.severe(
        message: message,
        error: Exception(code),
        trace: StackTrace.current,
      );
    }
    return SellUnexpectedFailure(code);
  }
}
