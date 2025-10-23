import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class CheckTorRequiredOnStartupUsecase {
  final WalletRepository _wallet;

  CheckTorRequiredOnStartupUsecase({required WalletRepository walletRepository})
    : _wallet = walletRepository;

  Future<bool> execute() async {
    try {
      return await _wallet.isTorRequired();
    } catch (e) {
      log.severe('CheckTorRequiredOnStartupUsecase: $e');
      return false;
    }
  }
}
