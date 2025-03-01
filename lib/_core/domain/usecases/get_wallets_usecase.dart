import 'package:bb_mobile/_core/domain/entities/wallet.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager.dart';

class GetWalletsUseCase {
  final WalletManager _manager;

  GetWalletsUseCase({
    required WalletManager walletManager,
  }) : _manager = walletManager;

  Future<List<Wallet>> execute() async {
    final wallets = await _manager.getWallets();
    return wallets;
  }
}
