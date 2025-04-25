import 'package:bb_mobile/core/storage/sqlite_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_extension.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    locator.registerLazySingleton<SqliteDatasource>(() => SqliteDatasource());
    locator.registerLazySingleton<WalletMetadataDatasource>(
      () => WalletMetadataDatasource(
        sqliteDatasource: locator<SqliteDatasource>(),
      ),
    );
  });

  tearDownAll(() {});
  group('WalletMetadata Sqlite Integration Tests', () {
    test('', () async {
      final metadata = WalletMetadataModel(
        xpubFingerprint: 'abc12345',
        isBitcoin: true,
        isLiquid: false,
        isMainnet: true,
        isTestnet: false,
        scriptType: 'bip84',
        xpub: 'xpub6CUGRUonZSQ4TWtTMmzXdrXDtypWKiKp5i1Lsfk...',
        externalPublicDescriptor: 'wpkh([abcd1234/84h/0h/0h]xpub.../0/*)',
        internalPublicDescriptor: 'wpkh([abcd1234/84h/0h/0h]xpub.../1/*)',
        source: 'hardware_wallet',
        latestEncryptedBackup: 1680000000,
        latestPhysicalBackup: 1681000000,
        isEncryptedVaultTested: true,
        isPhysicalBackupTested: true,
        isDefault: true,
        label: 'My Main Wallet',
        syncedAt: DateTime.now(),
      );

      final metadataSource = locator<WalletMetadataDatasource>();

      // Store a metadata
      await metadataSource.store(metadata);

      // Fetch one
      final fetchedMetadata = await metadataSource.get(metadata.id);
      expect(fetchedMetadata, isNotNull);
      expect(fetchedMetadata!.id, metadata.id);

      // Delete the only one
      await metadataSource.delete(metadata.origin);

      // Fetch all
      final fetchedMetadatas = await metadataSource.getAll();
      expect(fetchedMetadatas, isEmpty);
    });
  });
}
