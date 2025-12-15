import 'package:bb_mobile/core/primitives/network/network.dart';
import 'package:bb_mobile/features/wallets/domain/entities/wallet_entity.dart';

abstract class WalletsRepositoryPort {
  Future<WalletEntity> createWallet({
    String? label,
    required Network network,
    required bool isDefault,
    DateTime? birthday,
  });
  Future<WalletEntity> getWalletById(int walletId);
  Future<List<WalletEntity>> getAllWallets();
  Future<List<WalletEntity>> getMainnetWallets();
  Future<List<WalletEntity>> getTestnetWallets();
}
