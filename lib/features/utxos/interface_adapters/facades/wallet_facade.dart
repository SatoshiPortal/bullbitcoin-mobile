import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/utxos/domain/ports/wallet_port.dart';

class WalletFacade implements WalletPort {
  final GetWalletUsecase _getWalletUsecase;

  WalletFacade({required GetWalletUsecase getWalletUsecase})
    : _getWalletUsecase = getWalletUsecase;

  @override
  Future<Wallet?> getWallet(String walletId) {
    return _getWalletUsecase.execute(walletId);
  }
}
