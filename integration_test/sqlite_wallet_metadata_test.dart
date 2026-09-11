import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/wallet_signer_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_descriptor_key_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_signer_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  final sqlite = locator<SqliteDatabase>();
  final datasource = WalletMetadataDatasource(sqlite: sqlite);

  group('WalletMetadata Sqlite Integration Tests', () {
    test('can store and fetch a wallet metadata', () async {
      const fingerprint = 'master';
      const scriptType = ScriptType.bip84;

      final metadata = WalletMetadataModel(
        id: WalletMetadataService.encodeOrigin(
          fingerprint: fingerprint,
          network: Network.bitcoinMainnet,
          scriptType: scriptType,
        ),
        network: Network.bitcoinMainnet,
        signers: const [
          WalletSignerModel(
            id: 'signer-0',
            signer: Signer.local,
            signerDevice: null,
            descriptorKeys: [
              WalletDescriptorKeyModel(
                id: 'key-0',
                signerId: 'signer-0',
                masterFingerprint: fingerprint,
                xpubFingerprint: 'abc12345',
                xpub: 'xpub6CUGRUonZSQ4TWtTMmzXdrXDtypWKiKp5i1Lsfk...',
                derivationPath: "m/84'/0'/0'",
              ),
            ],
          ),
        ],
        publicDescriptor: 'wpkh([abcd1234/84h/0h/0h]xpub.../<0;1>/*)',
        latestEncryptedBackup: 1680000000,
        latestPhysicalBackup: 1681000000,
        isEncryptedVaultTested: true,
        isPhysicalBackupTested: true,
        isDefault: true,
        label: 'My Main Wallet',
        syncedAt: DateTime.now(),
      );

      // Clear any leftover row with the same id from a crashed prior run.
      await datasource.delete(metadata.id);

      await datasource.store(metadata);

      final fetchedMetadata = await datasource.fetch(metadata.id);
      expect(fetchedMetadata, metadata);

      await datasource.delete(metadata.id);

      // Ensure the row we inserted is gone. Scoped to our own id so the test is
      // isolated from any other wallet metadata already present in the database
      // (asserting the whole table is empty made this test order-dependent).
      final afterDelete = await datasource.fetch(metadata.id);
      expect(afterDelete, isNull);
    });
  });
}
