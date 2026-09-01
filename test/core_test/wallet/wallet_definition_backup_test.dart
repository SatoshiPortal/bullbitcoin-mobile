import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'dart:typed_data';

import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/descriptor_derivation.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/wallet_signing_material_resolver.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_unlock_session.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bdk extends Mock implements BdkWalletDatasource {}

class _Lwk extends Mock implements LwkWalletDatasource {}

class _Servers extends Mock implements ElectrumServersPort {}

class _Seeds extends Mock implements SeedDatasource {}

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
  late WalletSigningMaterialResolver signingMaterial;

  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    metadata = WalletMetadataDatasource(sqlite: database);
    signingMaterial = WalletSigningMaterialResolver(
      seedDatasource: _Seeds(),
      session: WalletUnlockSession(),
    );
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
      signingMaterialResolver: signingMaterial,
    );
    addTearDown(database.close);
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
          descriptor: definition.descriptor
              .replaceFirst('86241f88', '76241f88')
              .split('#')
              .first,
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
          descriptor:
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
      final source = (await WalletMetadataService.fromDescriptor(
        parsed as WatchOnlyDescriptorEntity,
        provenance: WalletProvenance.defaultSeed,
      )).copyWith(seedPassphraseUsed: true);
      await metadata.store(source.copyWith(isDefault: true));
      final definition = WalletDefinition(
        walletRef: source.id,
        network: Network.bitcoinMainnet,
        descriptor: DescriptorDerivation.combinePublicBitcoinDescriptors(
          externalDescriptor: source.externalPublicDescriptor,
          internalDescriptor: source.internalPublicDescriptor,
          network: Network.bitcoinMainnet,
        ),
        provenance: WalletProvenance.defaultSeed,
      );
      await metadata.delete(source.id);

      final result = await wallets.restoreWalletDefinition(definition);

      expect(result.status, WalletDefinitionRestoreStatus.conflict);
      expect(await metadata.fetch(source.id), isNull);
    },
  );

  test('returns only Bitcoin external and watch-only definitions', () async {
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
    final imported = bitcoin.copyWith(
      id: '${bitcoin.id}-imported',
      provenance: WalletProvenance.importedMnemonic,
    );
    final defaultWallet = bitcoin.copyWith(
      id: '${bitcoin.id}-default',
      isDefault: true,
      provenance: WalletProvenance.defaultSeed,
    );
    await metadata.storeAll([bitcoin, liquid, imported, defaultWallet]);

    final definitions = await wallets.getWalletDefinitions();

    expect(definitions.map((definition) => definition.walletRef).toSet(), {
      bitcoin.id,
    });
  });

  test('reports seed-derived recovery facts without descriptors', () async {
    final parsed = await WatchOnlyWalletEntity.parse(descriptor);
    final source = (await WalletMetadataService.fromDescriptor(
      parsed as WatchOnlyDescriptorEntity,
      provenance: WalletProvenance.importedMnemonic,
    )).copyWith(seedPassphraseUsed: true);
    await metadata.store(source);

    final facts = await wallets.getSeedDerivedWalletRecoveryFacts();

    expect(facts, hasLength(1));
    expect(facts.single.walletId, source.id);
    expect(facts.single.provenance, WalletProvenance.importedMnemonic);
    expect(facts.single.derivationPath, "m/84'/0'/0'");
    expect(facts.single.seedPassphraseUsed, isTrue);
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
    expect(changes, 2);
  });

  test('hides a passphrase wallet until its session is unlocked', () async {
    final parsed = await WatchOnlyWalletEntity.parse(descriptor);
    final source = (await WalletMetadataService.fromDescriptor(
      parsed as WatchOnlyDescriptorEntity,
      provenance: WalletProvenance.defaultSeedPassphrase,
    ));
    await metadata.store(source);

    expect(await wallets.getWallet(source.id), isNull);
    expect(await wallets.getWallets(), isEmpty);
    await expectLater(
      wallets.getWalletBalances(walletId: source.id),
      throwsA(isA<PassphraseWalletLockedException>()),
    );

    signingMaterial.loadPrivateCapabilityIfCurrent(
      generation: signingMaterial.beginPrivateCapabilityMount(),
      walletId: source.id,
      seed:
          Seed.mnemonic(
                mnemonicWords: const ['abandon'],
                passphrase: 'secret',
                bytes: Uint8List.fromList([1]),
                masterFingerprint: source.masterFingerprint,
              )
              as MnemonicSeed,
    );

    expect(await wallets.getWallet(source.id), isNotNull);
    expect(
      (await wallets.getWallets()).map((wallet) => wallet.id),
      contains(source.id),
    );

    signingMaterial.clearPrivateCapability();
    expect(await wallets.getWallet(source.id), isNull);
  });
}
