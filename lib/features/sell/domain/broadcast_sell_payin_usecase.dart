import 'package:bb_mobile/features/send/public/broadcast_failure.dart';
import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' hide Network;

class BroadcastSellPayinUsecase {
  final WalletFacade _wallet;
  final BroadcastBitcoinTransactionUsecase _broadcastBitcoinTransactionUsecase;
  final BroadcastLiquidTransactionUsecase _broadcastLiquidTransactionUsecase;

  const BroadcastSellPayinUsecase({
    required this._wallet,
    required this._broadcastBitcoinTransactionUsecase,
    required this._broadcastLiquidTransactionUsecase,
  });

  @useResult
  Future<Result<String, SellFailure>> bitcoin(
    String transaction, {
    required String walletId,
    required bool isPsbt,
    required Network network,
  }) async {
    try {
      final txid = await _broadcastBitcoinTransactionUsecase.execute(
        transaction,
        isPsbt: isPsbt,
        network: network,
      );
      _wallet.pollWallet(walletId, isActive: () => true).ignore();
      return Ok(txid);
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
      final txid = await _broadcastLiquidTransactionUsecase.execute(signedPset);
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
