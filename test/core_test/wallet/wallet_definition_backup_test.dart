import 'dart:typed_data';

import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:convert/convert.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bdk extends Mock implements BdkWalletDatasource {}

class _Lwk extends Mock implements LwkWalletDatasource {}

class _Servers extends Mock implements ElectrumServersPort {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const descriptor =
      'wpkh([86241f88/84h/0h/0h]xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7/<0;1>/*)#n8txaeah';
  final emptyBalance = BalanceModel(
    immatureSat: BigInt.zero,
    trustedPendingSat: BigInt.zero,
    untrustedPendingSat: BigInt.zero,
    confirmedSat: BigInt.zero,
    spendableSat: BigInt.zero,
    totalSat: BigInt.zero,
  );

  setUpAll(() {
    registerFallbackValue(
      const WalletModel.publicBdk(
        id: 'fallback',
        externalDescriptor: 'external',
        internalDescriptor: 'internal',
        isTestnet: false,
      ),
    );
  });

  late SqliteDatabase database;
  late WalletMetadataDatasource metadata;
  late WalletRepository wallets;

  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    metadata = WalletMetadataDatasource(sqlite: database);
    final bdk = _Bdk();
    final lwk = _Lwk();
    when(
      () => bdk.walletSyncFinishedStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => lwk.walletSyncFinishedStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => bdk.getBalance(wallet: any(named: 'wallet')),
    ).thenAnswer((_) async => emptyBalance);
    wallets = WalletRepository(
      walletMetadataDatasource: metadata,
      bdkWalletDatasource: bdk,
      lwkWalletDatasource: lwk,
      serversPort: _Servers(),
    );
    addTearDown(database.close);
  });

  test('restores an imported mnemonic as the same public wallet', () async {
    final parsed = await WatchOnlyWalletEntity.parse(descriptor);
    final source = await WalletMetadataService.fromDescriptor(
      parsed as WatchOnlyDescriptorEntity,
      birthday: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      provenance: WalletProvenance.importedMnemonic,
      seedPassphraseUsed: true,
    );
    await metadata.store(source);
    final definition = (await wallets.getWalletDefinitions()).single;
    await metadata.delete(source.id);

    final result = await wallets.restoreWalletDefinition(definition);
    final restored = await metadata.fetch(source.id);

    expect(result.status, WalletDefinitionRestoreStatus.created);
    expect(result.walletRef, source.id);
    expect(restored?.externalPublicDescriptor, source.externalPublicDescriptor);
    expect(restored?.internalPublicDescriptor, source.internalPublicDescriptor);
    expect(restored?.birthday, source.birthday);
    expect(restored?.provenance, WalletProvenance.importedMnemonic);
    expect(restored?.seedPassphraseUsed, isTrue);
  });

  test(
    'is idempotent for the same id and conflicts on changed descriptors',
    () async {
      final parsed = await WatchOnlyWalletEntity.parse(descriptor);
      final source = await WalletMetadataService.fromDescriptor(
        parsed as WatchOnlyDescriptorEntity,
      );
      await metadata.store(source);
      final definition = (await wallets.getWalletDefinitions()).single;

      final unchanged = await wallets.restoreWalletDefinition(definition);
      final changed = await wallets.restoreWalletDefinition(
        WalletDefinition(
          walletRef: definition.walletRef,
          network: definition.network,
          receiveDescriptor: definition.changeDescriptor!,
          changeDescriptor: definition.receiveDescriptor,
          masterFingerprint: definition.masterFingerprint,
          provenance: definition.provenance,
        ),
      );

      expect(unchanged.status, WalletDefinitionRestoreStatus.alreadyPresent);
      expect(changed.status, WalletDefinitionRestoreStatus.conflict);
    },
  );

  test('reports a currently unsupported public descriptor as input failure', () {
    return expectLater(
      wallets.restoreWalletDefinition(
        WalletDefinition(
          walletRef: 'future-wallet',
          network: Network.bitcoinMainnet,
          receiveDescriptor:
              'tr(79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798)',
          provenance: WalletProvenance.watchOnly,
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'does not restore a missing seed-recoverable wallet as watch-only',
    () async {
      final parsed = await WatchOnlyWalletEntity.parse(descriptor);
      final source = await WalletMetadataService.fromDescriptor(
        parsed as WatchOnlyDescriptorEntity,
        provenance: WalletProvenance.defaultSeed,
        seedPassphraseUsed: true,
      );
      await metadata.store(source.copyWith(isDefault: true));
      final definition = (await wallets.getWalletDefinitions()).single;
      await metadata.delete(source.id);

      final result = await wallets.restoreWalletDefinition(definition);

      expect(result.status, WalletDefinitionRestoreStatus.conflict);
      expect(await metadata.fetch(source.id), isNull);
    },
  );

  test('excludes Liquid wallets from the definitions backup', () async {
    final parsed = await WatchOnlyWalletEntity.parse(descriptor);
    final bitcoin = await WalletMetadataService.fromDescriptor(
      parsed as WatchOnlyDescriptorEntity,
    );
    final liquid = bitcoin.copyWith(
      id: WalletMetadataService.encodeOrigin(
        fingerprint: bitcoin.masterFingerprint,
        network: Network.liquidMainnet,
        scriptType: ScriptType.bip84,
      ),
    );
    await metadata.storeAll([bitcoin, liquid]);

    final definitions = await wallets.getWalletDefinitions();

    expect(definitions.map((definition) => definition.walletRef), [bitcoin.id]);
  });

  test('emits only backed-up catalogue changes', () async {
    final parsed = await WatchOnlyWalletEntity.parse(descriptor);
    final source = await WalletMetadataService.fromDescriptor(
      parsed as WatchOnlyDescriptorEntity,
    );
    var changes = 0;
    final subscription = metadata.catalogChanges.listen((_) => changes++);
    addTearDown(subscription.cancel);

    await metadata.store(source);
    expect(changes, 1);
    await metadata.store(source.copyWith(label: 'renamed'));
    expect(changes, 1);
    await metadata.store(
      source.copyWith(provenance: WalletProvenance.importedMnemonic),
    );
    expect(changes, 2);
    await metadata.delete(source.id);
    expect(changes, 3);
  });

  test(
    're-importing a mnemonic upgrades its restored watch-only shadow',
    () async {
      final mnemonic = bip39.Mnemonic.fromWords(
        words: List.generate(11, (_) => 'zoo') + ['wrong'],
      );
      final bytes = Uint8List.fromList(mnemonic.seed);
      final seed = MnemonicSeed(
        mnemonicWords: mnemonic.words,
        bytes: bytes,
        masterFingerprint: hex.encode(
          bip32.Bip32Keys.fromSeed(bytes).fingerprint,
        ),
      );
      final original = await wallets.createWallet(
        seed: seed,
        network: Network.bitcoinMainnet,
        scriptType: ScriptType.bip84,
        provenance: WalletProvenance.importedMnemonic,
        birthday: null,
      );
      final definition = (await wallets.getWalletDefinitions()).single;
      await metadata.delete(original.id);

      final restored = await wallets.restoreWalletDefinition(definition);
      expect(restored.status, WalletDefinitionRestoreStatus.created);
      final shadow = await metadata.fetch(original.id);
      expect(shadow?.signer.toEntity(), SignerEntity.none);

      final upgraded = await wallets.createWallet(
        seed: seed,
        network: Network.bitcoinMainnet,
        scriptType: ScriptType.bip84,
        provenance: WalletProvenance.importedMnemonic,
        birthday: null,
      );

      expect(upgraded.id, original.id);
      final rows = await metadata.fetchAll();
      expect(rows, hasLength(1));
      expect(rows.single.signer.toEntity(), SignerEntity.local);
      expect(rows.single.provenance, WalletProvenance.importedMnemonic);
    },
  );
}
