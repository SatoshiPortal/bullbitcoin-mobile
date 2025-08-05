import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_storage_keys.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/secure_storage_datasource.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

// create an enum called Migration with two values v4 and v5
enum MigrationRequired { v4, v5 }

class RequiresMigrationUsecase {
  final MigrationSecureStorageDatasource _migrationSecureStorageDatasource;
  final WalletRepository _newWalletRepository;

  RequiresMigrationUsecase(
    this._migrationSecureStorageDatasource,
    this._newWalletRepository,
  );

  Future<MigrationRequired?> execute() async {
    final fromVersion = await _migrationSecureStorageDatasource.fetch(
      key: OldStorageKeys.version.name,
    );
    if (fromVersion == null) {
      return null;
    }
    if (fromVersion.startsWith('0.1') ||
        fromVersion.startsWith('0.2') ||
        fromVersion.startsWith('0.3')) {
      return MigrationRequired.v4;
    }

    final newMainnetDefaultWallets = await _newWalletRepository.getWallets(
      onlyDefaults: true,
      environment: Environment.mainnet,
    );
    if (newMainnetDefaultWallets.length < 2 && fromVersion.startsWith('0.4')) {
      return MigrationRequired.v5;
    }
    return null;
  }
}
