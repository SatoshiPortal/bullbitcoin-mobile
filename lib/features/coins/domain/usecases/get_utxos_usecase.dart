import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/coins_error.dart';

/// Thin feature wrapper over the core [GetWalletUtxosUsecase].
///
/// Returns the rich [WalletUtxo] list (already carrying `confirmations`,
/// `isFrozen`, keychain and labels) and maps any data-layer failure to the
/// feature's sealed [CoinsError] at this boundary.
class GetUtxosUsecase {
  GetUtxosUsecase({required this._getWalletUtxosUsecase});

  final GetWalletUtxosUsecase _getWalletUtxosUsecase;

  Future<List<WalletUtxo>> execute({required String walletId}) async {
    try {
      return await _getWalletUtxosUsecase.execute(walletId: walletId);
    } on GetUtxosUsecaseException {
      throw const CoinsError.loadFailed();
    } catch (e) {
      throw CoinsError.unexpected(message: e.toString());
    }
  }
}
