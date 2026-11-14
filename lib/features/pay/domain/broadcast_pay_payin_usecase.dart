import 'package:bb_mobile/features/send/public/broadcast_failure.dart';
import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/send/public/send_facade.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' hide Network;

class BroadcastPayPayinUsecase {
  final WalletFacade _wallet;
  final SendFacade _send;

  const BroadcastPayPayinUsecase({required this._wallet, required this._send});

  @useResult
  Future<Result<String, PayFailure>> bitcoin(
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
        PaySpendBlockedFailure(busy: e.status == BitcoinSpendStatus.busy),
      );
    } on Exception catch (e) {
      return Err(_broadcastFailure(e, 'bitcoin'));
    }
  }

  @useResult
  Future<Result<String, PayFailure>> liquid(
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

  PayFailure _broadcastFailure(Exception error, String chain) {
    const code = 'pay_payin_broadcast_failed';
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
    return PayUnexpectedFailure(code);
  }
}
