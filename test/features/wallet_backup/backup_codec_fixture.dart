import 'package:bb_mobile/core/bip85/data/bip85_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/wallet_backup_codec_repository_impl.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_inventory_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_metadata_backup_repository.dart';
import 'package:mocktail/mocktail.dart';

class _Database extends Fake implements SqliteDatabase {}

class _Manifest extends Fake implements KeychainManifestFacade {}

class _Inventory extends Fake implements WalletInventoryBackupRepository {}

class _Metadata extends Fake implements WalletMetadataBackupRepository {}

class _Wallets extends Fake implements WalletMetadataDatasource {}

class _Bip85 extends Fake implements Bip85Datasource {}

WalletBackupCodecRepositoryImpl backupCodecFixture(BullVaultFacade vaults) =>
    WalletBackupCodecRepositoryImpl(
      vaults: vaults,
      database: _Database(),
      manifest: _Manifest(),
      inventory: _Inventory(),
      metadata: _Metadata(),
      wallets: _Wallets(),
      bip85: _Bip85(),
    );
