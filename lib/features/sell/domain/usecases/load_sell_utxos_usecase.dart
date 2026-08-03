import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:meta/meta.dart';

class LoadSellUtxosUsecase {
  final GetWalletUtxosUsecase _getWalletUtxosUsecase;

  LoadSellUtxosUsecase({required this._getWalletUtxosUsecase});

  @useResult
  Future<Result<List<WalletUtxo>, SellFailure>> execute({
    required String walletId,
  }) async {
    try {
      final utxos = await _getWalletUtxosUsecase.execute(walletId: walletId);
      return Ok(utxos);
    } catch (e, st) {
      log.severe(message: 'sell load UTXOs failed', error: e, trace: st);
      return Err(SellLoadUtxosFailure(e.toString()));
    }
  }
}
