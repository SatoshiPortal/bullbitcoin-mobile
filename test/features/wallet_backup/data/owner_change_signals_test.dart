import 'package:bb_mobile/core/bip85/data/bip85_datasource.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_server_network.dart';
import 'package:bb_mobile/features/electrum_settings/data/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/features/electrum_settings/data/electrum_settings_storage_datasource.dart';
import 'package:bb_mobile/features/electrum_settings/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/models/electrum_settings_model.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/datasources/mempool_server_storage_datasource.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/datasources/mempool_settings_storage_datasource.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/models/mempool_server_model.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/models/mempool_settings_model.dart';
import 'package:bb_mobile/features/settings/data/settings_datasource.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/bip85_derivations_table.dart';
import 'package:bb_mobile/core/storage/tables/wallet_signer_table.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_signer_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_descriptor_key_model.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SqliteDatabase database;
  setUp(() async {
    database = SqliteDatabase(NativeDatabase.memory());
    await database.select(database.settings).get();
  });
  tearDown(() => database.close());
  Future<void> settle() => Future<void>.delayed(Duration.zero);
  test('settings invalidations occur after transactions and expose committed facts', () async {
    final owner = SettingsDatasource(sqlite: database);
    var changes = 0;
    final subscription = owner.changes.listen((_) => changes++);
    addTearDown(subscription.cancel);
    await database.transaction(() async {
      await owner.setCurrency('USD');
      await owner.setLanguage(Language.franceFrench);
      expect(changes, 0);
    });
    await settle();
    expect(changes, 1);
    await expectLater(
      database.transaction(() async {
        await owner.setCurrency('CAD');
        throw Exception('rollback fixture');
      }),
      throwsException,
    );
    await settle();
    expect((await owner.fetch()).currency, 'USD');
  });
  test('wallet labels and signer-only edits notify the wallet owner', () async {
    final owner = WalletMetadataDatasource(sqlite: database);
    var changes = 0;
    final subscription = owner.changes.listen((_) => changes++);
    addTearDown(subscription.cancel);
    final metadata = WalletMetadataModel(
      id: 'wallet',
      networkCode: Network.bitcoinMainnet.name,
      publicDescriptor: 'public fixture',
      isDefault: false,
      isEncryptedVaultTested: false,
      isPhysicalBackupTested: false,
      signers: [
        WalletSignerModel(
          id: 'signer',
          signer: Signer.remote,
          signerDevice: SignerDevice.ledgerNanoX,
          descriptorKeys: [
            WalletDescriptorKeyModel(
              id: 'key',
              signerId: 'signer',
              masterFingerprint: 'aabbccdd',
              xpubFingerprint: '11223344',
              xpub: 'public fixture',
              derivationPath: null,
            ),
          ],
        ),
      ],
    );
    await owner.store(metadata);
    await settle();
    expect(changes, 1);
    await owner.updateSignerRegistrationName(
      walletId: 'wallet',
      signerId: 'signer',
      registrationName: 'New annotation',
    );
    await settle();
    expect(changes, 2);
    await owner.store(
      (await owner.fetch('wallet'))!.copyWith(label: 'New name'),
    );
    await settle();
    expect(changes, 3);
  });
  test('BIP85 alias and status edits notify without deriving a key', () async {
    const path = "39'/0'/12'/1'";
    await database
        .into(database.bip85Derivations)
        .insert(
          Bip85DerivationsCompanion.insert(
            path: path,
            xprvFingerprint: 'aabbccdd',
            application: Bip85ApplicationColumn.bip39,
            status: Bip85StatusColumn.active,
          ),
        );
    final owner = Bip85Datasource(sqlite: database);
    var changes = 0;
    final subscription = owner.changes.listen((_) => changes++);
    addTearDown(subscription.cancel);
    await owner.alias(path, 'New name');
    await settle();
    expect(changes, 1);
    await owner.revoke(path);
    await settle();
    expect(changes, 2);
  });
  test(
    'Electrum batch priorities and deletion notify through their owner',
    () async {
      final owner = ElectrumServerStorageDatasource(sqlite: database);
      var changes = 0;
      final subscription = owner.changes.listen((_) => changes++);
      addTearDown(subscription.cancel);
      await owner.storeBatch([
        ElectrumServerModel(
          url: 'one.example:50002',
          network: ElectrumServerNetwork.bitcoinMainnet,
          isCustom: true,
          priority: 1,
        ),
        ElectrumServerModel(
          url: 'two.example:50002',
          network: ElectrumServerNetwork.bitcoinMainnet,
          isCustom: true,
          priority: 0,
        ),
      ]);
      await settle();
      expect(changes, 1);
      expect(
        await owner.deleteServer(
          'one.example:50002',
          network: ElectrumServerNetwork.bitcoinMainnet,
        ),
        isTrue,
      );
      await settle();
      expect(changes, 2);
    },
  );
  test('Electrum settings notify through their owner', () async {
    final owner = ElectrumSettingsStorageDatasource(sqlite: database);
    var changes = 0;
    final subscription = owner.changes.listen((_) => changes++);
    addTearDown(subscription.cancel);
    await owner.store(
      ElectrumSettingsModel(
        network: ElectrumServerNetwork.bitcoinMainnet,
        validateDomain: true,
        stopGap: 42,
        timeout: 10,
        retry: 3,
      ),
    );
    await settle();
    expect(changes, 1);
  });
  test(
    'Mempool custom server selection and removal notify through their owner',
    () async {
      final owner = MempoolServerStorageDatasource(sqlite: database);
      var changes = 0;
      final subscription = owner.changes.listen((_) => changes++);
      addTearDown(subscription.cancel);
      await owner.store(
        MempoolServerModel(
          url: 'mempool.example',
          isTestnet: false,
          isLiquid: false,
          isCustom: true,
        ),
      );
      await settle();
      expect(changes, 1);
      expect(
        await owner.deleteCustomServer(MempoolServerNetwork.bitcoinMainnet),
        isTrue,
      );
      await settle();
      expect(changes, 2);
    },
  );
  test('Mempool fee-source changes notify through their owner', () async {
    final owner = MempoolSettingsStorageDatasource(sqlite: database);
    var changes = 0;
    final subscription = owner.changes.listen((_) => changes++);
    addTearDown(subscription.cancel);
    await owner.store(
      MempoolSettingsModel(
        network: MempoolServerNetwork.bitcoinMainnet.networkString,
        useForFeeEstimation: false,
      ),
    );
    await settle();
    expect(changes, 1);
  });
}
