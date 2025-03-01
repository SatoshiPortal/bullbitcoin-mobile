import 'package:bb_mobile/core/domain/entities/wallet.dart';
import 'package:bb_mobile/core/domain/repositories/wallet_manager_repository.dart';

class GetWalletsUseCase {
  final WalletManagerRepository _manager;

  GetWalletsUseCase({
    required WalletManagerRepository walletManager,
  }) : _manager = walletManager;

  Future<List<Wallet>> execute() async {
    final wallets = await _manager.getWallets();
    return wallets;
  }
}
