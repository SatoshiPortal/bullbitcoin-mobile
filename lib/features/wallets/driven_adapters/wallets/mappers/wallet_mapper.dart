import 'package:bb_mobile/core/infra/database/sqlite_database.dart';
import 'package:bb_mobile/features/wallets/domain/entities/wallet_entity.dart';

class WalletMapper {
  static WalletEntity walletMetadataRowToWalletEntity(WalletMetadataRow row) {
    return WalletEntity.rehydrate(
      id: row.id,
      label: row.label,
      isDefault: row.isDefault,
      network: row.network,
      mnemonicTestedAt: row.mnemonicTestedAt,
      encryptedVaultTestedAt: row.encryptedVaultTestedAt,
      birthday: row.birthday,
    );
  }
}
