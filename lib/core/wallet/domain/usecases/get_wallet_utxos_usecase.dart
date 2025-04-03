import 'package:bb_mobile/core/wallet/domain/entity/utxo.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_manager_service.dart';

class GetWalletUtxosUsecase {
  final WalletManagerService _walletService;

  GetWalletUtxosUsecase({
    required WalletManagerService walletService,
  }) : _walletService = walletService;

  Future<List<Utxo>> execute({required String walletId}) async {
    return await _walletService.getUnspentUtxos(walletId: walletId);
  }
}
