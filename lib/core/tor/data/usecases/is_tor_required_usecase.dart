import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class IsTorRequiredUsecase {
  final WalletRepository _wallet;

  IsTorRequiredUsecase({required WalletRepository walletRepository})
    : _wallet = walletRepository;

  Future<bool> execute() async {
    try {
      return await _wallet.isTorRequired();
    } catch (e) {
      log.severe('$IsTorRequiredUsecase: $e');
      return false;
    }
  }
}
