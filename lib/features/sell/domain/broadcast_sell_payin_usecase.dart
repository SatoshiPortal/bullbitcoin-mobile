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
    } catch (e, st) {
      log.severe(
        message: 'Failed to broadcast the Bitcoin sell payin',
        error: e,
        trace: st,
      );
      return Err(SellUnexpectedFailure('$e'));
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
    } catch (e, st) {
      log.severe(
        message: 'Failed to broadcast the Liquid sell payin',
        error: e,
        trace: st,
      );
      return Err(SellUnexpectedFailure('$e'));
    }
  }
}
