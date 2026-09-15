import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'dart:typed_data';

import 'package:bb_mobile/core/utils/bip32_derivation.dart';

import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/wallet_signing_material_resolver.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_unlock_session.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:bb_mobile/features/wallet_backup/data/models/wallet_definitions_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bb_mobile/core/storage/tables/wallet_signer_table.dart';

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
        descriptor: 'external',
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
    // Descriptor parsing is pure and has no I/O, so delegate it to the real
    // implementation rather than hand-rolling a script identity here.
    when(
      () => bdk.parsePublicTwoPathDescriptor(
        descriptor: any(named: 'descriptor'),
        isTestnet: any(named: 'isTestnet'),
      ),
    ).thenAnswer(
      (invocation) => BdkFacade.parsePublicTwoPathDescriptor(
        descriptor: invocation.namedArguments[#descriptor] as String,
        isTestnet: invocation.namedArguments[#isTestnet] as bool,
      ),
    );
    wallets = WalletRepository(
      walletMetadataDatasource: metadata,
      bdkWalletDatasource: bdk,
      lwkWalletDatasource: lwk,
      serversPort: _Servers(),
      signingMaterialResolver: signingMaterial,
    );
    addTearDown(database.close);
  });

  /// Imports [descriptor] the way the app does, then applies the provenance
  /// facts the test is about. Going through the repository keeps the wallet id
  /// identical to the one a restore computes.
  Future<WalletMetadataModel> importSource({
    WalletProvenance provenance = WalletProvenance.watchOnly,
    bool isDefault = false,
    bool? seedPassphraseUsed,
  }) async {
    final imported = await wallets.importDescriptor(
      descriptor: descriptor,
      network: Network.bitcoinMainnet,
      label: '',
    );
    final stored = (await metadata.fetch(imported.id))!;
    final updated = stored.copyWith(
      provenance: provenance,
      isDefault: isDefault,
      seedPassphraseUsed: seedPassphraseUsed,
    );
    await metadata.store(updated);
    return updated;
  }

  test(
    'is idempotent for the same id and conflicts on changed descriptors',
    () async {
      await importSource();
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

  test('restores signer recovery facts through the codec and SQLite', () async {
    final source = await importSource(provenance: WalletProvenance.descriptor);
    final signer = source.signers.single;
    final annotated = source.copyWith(
      signers: [
        signer.copyWith(
          signer: Signer.local,
          registrationName: 'My registered policy',
          localSeedFingerprint: 'aabbccdd',
          descriptorKeys: [
            signer.descriptorKeys.single.copyWith(requiresPassphrase: true),
          ],
        ),
      ],
    );
    await metadata.store(annotated);
    const codec = WalletDefinitionsCodec();
    final payload = codec.encode(await wallets.getWalletDefinitions());
    await metadata.delete(source.id);
    expect(await metadata.fetchAll(), isEmpty);

    final restored = await wallets.restoreWalletDefinition(
      codec.decode(payload).single,
    );

    expect(restored.status, WalletDefinitionRestoreStatus.created);
    final stored = (await metadata.fetch(source.id))!;
    expect(stored.signers, annotated.signers);
    expect(codec.encode(await wallets.getWalletDefinitions()), payload);
  });

  test(
    'restores a seed-origin reference without replacing it with a hash',
    () async {
      const recordedRef = 'wpkh([86241f88/84h/0h/0h])';
      final definition = WalletDefinition(
        walletRef: recordedRef,
        network: Network.bitcoinMainnet,
        descriptor: descriptor,
        provenance: WalletProvenance.defaultSeedPassphrase,
      );

      final restored = await wallets.restoreWalletDefinition(definition);
      expect(restored.status, WalletDefinitionRestoreStatus.created);
      expect(restored.walletRef, recordedRef);
      expect((await metadata.fetchAll()).map((wallet) => wallet.id), [
        recordedRef,
      ]);
      expect(
        (await metadata.fetch(recordedRef))!.provenance,
        WalletProvenance.defaultSeedPassphrase,
      );
      expect(
        (await wallets.restoreWalletDefinition(definition)).status,
        WalletDefinitionRestoreStatus.alreadyPresent,
      );
    },
  );

  for (final network in [Network.bitcoinMainnet, Network.bitcoinTestnet]) {
    test(
      'malformed private definition is rejected without leaking or writing on ${network.name}',
      () async {
        final privateKey = Bip32Derivation.getXprvFromSeed(
          Uint8List.fromList(List.generate(32, (index) => index)),
          network,
        );
        await expectLater(
          wallets.restoreWalletDefinition(
            WalletDefinition(
              walletRef: 'malformed-private-input',
              network: network,
              descriptor: 'wsh($privateKey())',
              provenance: WalletProvenance.watchOnly,
            ),
          ),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString().contains(privateKey),
              'private key appears in diagnostic',
              isFalse,
            ),
          ),
        );
        expect(await metadata.fetchAll(), isEmpty);
      },
    );

    test(
      'definition import rejects private descriptors on ${network.name}',
      () async {
        final privateKey = Bip32Derivation.getXprvFromSeed(
          Uint8List.fromList(List.generate(32, (index) => index)),
          network,
        );
        final privateDescriptor = 'wpkh($privateKey/<0;1>/*)';
        await expectLater(
          wallets.restoreWalletDefinition(
            WalletDefinition(
              walletRef: 'private-input',
              network: network,
              descriptor: privateDescriptor,
              provenance: WalletProvenance.watchOnly,
            ),
          ),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString().contains(privateKey),
              'does not expose the private key',
              isFalse,
            ),
          ),
        );
        expect(await metadata.fetchAll(), isEmpty);
      },
    );
  }

  test(
    'equivalent descriptor notation does not cause a restore conflict',
    () async {
      final source = await importSource();
      final definition = (await wallets.getWalletDefinitions()).single;
      for (final equivalent in [
        descriptor.split('#').first,
        descriptor.split('#').first.replaceFirst('84h/0h/0h', "84'/0'/0'"),
        descriptor.split('#').first.replaceFirst('/<0;1>/*', '/0/*'),
      ]) {
        final restored = await wallets.restoreWalletDefinition(
          WalletDefinition(
            walletRef: definition.walletRef,
            network: definition.network,
            descriptor: equivalent,
            provenance: definition.provenance,
          ),
        );
        expect(restored.status, WalletDefinitionRestoreStatus.alreadyPresent);
        expect(await metadata.fetchAll(), [source]);
      }
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
      final source = await importSource(
        provenance: WalletProvenance.defaultSeed,
        isDefault: true,
        seedPassphraseUsed: true,
      );
      final definition = WalletDefinition(
        walletRef: source.id,
        network: Network.bitcoinMainnet,
        descriptor: source.publicDescriptor,
        provenance: WalletProvenance.defaultSeed,
      );
      await metadata.delete(source.id);

      final result = await wallets.restoreWalletDefinition(definition);

      expect(result.status, WalletDefinitionRestoreStatus.conflict);
      expect(await metadata.fetch(source.id), isNull);
    },
  );

  test('returns only Bitcoin external and watch-only definitions', () async {
    final bitcoin = await importSource();
    final liquid = bitcoin.copyWith(
      id: 'elwpkh([86241f88/84h/1776h/0h])',
      network: Network.liquidMainnet,
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
    // Seed-derived wallets keep their BIP32 origin as the id; only descriptor
    // imports get a hashed one, so this fixture is built the seed way.
    final imported = await importSource();
    final source = imported.copyWith(
      id: 'wpkh([86241f88/84h/0h/0h])',
      provenance: WalletProvenance.importedMnemonic,
      seedPassphraseUsed: true,
    );
    await metadata.delete(imported.id);
    await metadata.store(source);

    final facts = await wallets.getSeedDerivedWalletRecoveryFacts();

    expect(facts, hasLength(1));
    expect(facts.single.walletId, source.id);
    expect(facts.single.provenance, WalletProvenance.importedMnemonic);
    expect(facts.single.derivationPath, "m/84'/0'/0'");
    expect(facts.single.seedPassphraseUsed, isTrue);
  });

  test(
    'recovers a descriptor-adopted default after a fresh seed restore',
    () async {
      final seed = SeedModel.mnemonic(
        mnemonicWords: [...List.filled(11, 'abandon'), 'about'],
      ).toEntity();
      final derived = await WalletMetadataService.deriveFromSeed(
        seed: seed,
        network: Network.bitcoinMainnet,
        scriptType: ScriptType.bip84,
        isDefault: true,
        provenance: WalletProvenance.defaultSeed,
      );
      final imported = await wallets.importDescriptor(
        descriptor: derived.publicDescriptor,
        network: derived.network,
        label: 'Imported before seed recovery',
      );
      await wallets.createWallet(
        seed: seed,
        network: derived.network,
        scriptType: ScriptType.bip84,
        isDefault: true,
        provenance: WalletProvenance.defaultSeed,
        birthday: null,
      );
      final recorded =
          (await wallets.getSeedDerivedWalletRecoveryFacts()).single;
      expect(recorded.walletId, imported.id);
      expect(recorded.walletId, isNot(derived.id));
      expect(
        await wallets.resolveSeedDerivedRecoveryWalletId(
          walletId: derived.id,
          seedFingerprint: seed.masterFingerprint,
          network: recorded.network,
          scriptType: recorded.scriptType,
          provenance: recorded.provenance,
          derivationPath: recorded.derivationPath,
          seedPassphraseUsed: recorded.seedPassphraseUsed,
        ),
        imported.id,
        reason:
            'Origin-ID backups also recover onto a descriptor-adopted default',
      );

      // A fresh installation derives the same wallet, but not its adopted ID.
      await metadata.delete(imported.id);
      final recovered = await wallets.createWallet(
        seed: seed,
        network: derived.network,
        scriptType: ScriptType.bip84,
        isDefault: true,
        provenance: WalletProvenance.defaultSeed,
        birthday: null,
      );
      expect(recovered.id, derived.id);
      expect(
        await wallets.resolveSeedDerivedRecoveryWalletId(
          walletId: recorded.walletId,
          seedFingerprint: seed.masterFingerprint,
          network: recorded.network,
          scriptType: recorded.scriptType,
          provenance: recorded.provenance,
          derivationPath: recorded.derivationPath,
          seedPassphraseUsed: recorded.seedPassphraseUsed,
        ),
        recovered.id,
      );
      expect(await metadata.fetch(recorded.walletId), isNull);
      expect((await metadata.fetchAll()).single.id, recovered.id);
      expect(
        await wallets.resolveSeedDerivedRecoveryWalletId(
          walletId: 'unrelated-recorded-id',
          seedFingerprint: seed.masterFingerprint,
          network: recorded.network,
          scriptType: recorded.scriptType,
          provenance: recorded.provenance,
          derivationPath: recorded.derivationPath,
          seedPassphraseUsed: recorded.seedPassphraseUsed,
        ),
        isNull,
        reason: 'Matching fingerprint and path cannot alias arbitrary IDs',
      );

      // Keep the same fingerprint/path in the signer facts, but change the
      // descriptor's full key. A fingerprint-only fallback would accept this.
      final local = (await metadata.fetch(recovered.id))!;
      await metadata.store(local.copyWith(publicDescriptor: descriptor));
      expect(
        await wallets.resolveSeedDerivedRecoveryWalletId(
          walletId: recorded.walletId,
          seedFingerprint: seed.masterFingerprint,
          network: recorded.network,
          scriptType: recorded.scriptType,
          provenance: recorded.provenance,
          derivationPath: recorded.derivationPath,
          seedPassphraseUsed: recorded.seedPassphraseUsed,
        ),
        isNull,
        reason:
            'Descriptor identity must prove the complete key, not its fingerprint',
      );
    },
  );

  for (final isDefault in [false, true]) {
    for (final passphraseUsed in [false, true]) {
      test(
        'descriptor upgrade retains recovery identity (default: $isDefault, passphrase: $passphraseUsed)',
        () async {
          final seed = SeedModel.mnemonic(
            mnemonicWords: [...List.filled(11, 'abandon'), 'about'],
            passphrase: passphraseUsed ? 'synthetic-upgrade-passphrase' : null,
          ).toEntity();
          final provenance = isDefault
              ? WalletProvenance.defaultSeed
              : WalletProvenance.importedMnemonic;
          final derived = await WalletMetadataService.deriveFromSeed(
            seed: seed,
            network: Network.bitcoinMainnet,
            scriptType: ScriptType.bip84,
            isDefault: isDefault,
            provenance: provenance,
          );
          final imported = await wallets.importDescriptor(
            descriptor: derived.publicDescriptor,
            network: derived.network,
            label: 'Saved wallet label',
          );
          final birthday = DateTime.utc(2020, 1, 1);
          await metadata.store(
            (await metadata.fetch(imported.id))!.copyWith(birthday: birthday),
          );

          final upgraded = await wallets.createWallet(
            seed: seed,
            network: derived.network,
            scriptType: ScriptType.bip84,
            isDefault: isDefault,
            provenance: provenance,
            birthday: DateTime.utc(2026, 1, 1),
          );

          final stored = (await metadata.fetch(imported.id))!;
          expect(upgraded.id, imported.id);
          expect(upgraded.id, isNot(derived.id));
          expect(stored.provenance, provenance);
          expect(stored.seedPassphraseUsed, passphraseUsed);
          expect(stored.birthday, birthday);
          expect(
            stored.label,
            isDefault ? 'Secure Bitcoin' : 'Saved wallet label',
          );
          expect(stored.signers.single.signer, Signer.local);
          expect(await metadata.fetchAll(), hasLength(1));
          expect(await wallets.getWalletDefinitions(), isEmpty);
          expect(await wallets.getLocallyKeyedWalletIds(), {imported.id});
          final fact =
              (await wallets.getSeedDerivedWalletRecoveryFacts()).single;
          expect(fact.walletId, imported.id);
          expect(fact.derivationPath, "m/84'/0'/0'");
          expect(fact.scriptType, ScriptType.bip84);
          expect(fact.seedPassphraseUsed, passphraseUsed);
          expect(
            await wallets.resolveSeedDerivedRecoveryWalletId(
              walletId: fact.walletId,
              seedFingerprint: seed.masterFingerprint,
              network: fact.network,
              scriptType: fact.scriptType,
              provenance: provenance,
              derivationPath: fact.derivationPath,
              seedPassphraseUsed: passphraseUsed,
            ),
            imported.id,
          );
        },
      );
    }
  }

  test(
    'recovery facts use signer paths, not a descriptor-origin wallet ID',
    () async {
      final source = await importSource(
        provenance: WalletProvenance.importedMnemonic,
        seedPassphraseUsed: false,
      );
      final facts = await wallets.getSeedDerivedWalletRecoveryFacts();
      expect(facts.single.walletId, source.id);
      expect(facts.single.scriptType, ScriptType.bip84);
      expect(facts.single.derivationPath, "m/84'/0'/0'");
    },
  );

  test('emits only backed-up catalogue changes', () async {
    final source = await importSource();
    var changes = 0;
    final subscription = metadata.catalogChanges.listen((_) => changes++);
    addTearDown(subscription.cancel);

    // Storing the same definition again is not a change.
    await metadata.store(source);
    expect(changes, 0);
    await metadata.store(source.copyWith(label: 'renamed'));
    expect(changes, 0);
    await metadata.store(
      source.copyWith(provenance: WalletProvenance.importedMnemonic),
    );
    expect(changes, 1);
    await metadata.delete(source.id);
    expect(changes, 1);
  });

  test('a signer device change dirties a backed-up definition once', () async {
    final source = await importSource(
      provenance: WalletProvenance.externalSigner,
    );
    var changes = 0;
    final subscription = metadata.catalogChanges.listen((_) => changes++);
    addTearDown(subscription.cancel);

    final signerId = source.signers.single.id;
    expect(
      await metadata.updateSignerDevice(
        walletId: source.id,
        signerId: signerId,
        signer: Signer.remote,
        signerDevice: SignerDevice.coldcardQ,
      ),
      isTrue,
    );
    expect(changes, 1);

    // Writing the same device again is not a change.
    await metadata.updateSignerDevice(
      walletId: source.id,
      signerId: signerId,
      signer: Signer.remote,
      signerDevice: SignerDevice.coldcardQ,
    );
    expect(changes, 1);
  });

  test(
    'a registration name change dirties a backed-up definition once',
    () async {
      final source = await importSource(
        provenance: WalletProvenance.externalSigner,
      );
      var changes = 0;
      final subscription = metadata.catalogChanges.listen((_) => changes++);
      addTearDown(subscription.cancel);
      final signerId = source.signers.single.id;
      expect(
        await metadata.updateSignerRegistrationName(
          walletId: source.id,
          signerId: signerId,
          registrationName: 'My hardware policy',
        ),
        isTrue,
      );
      expect(changes, 1);
      expect(
        await metadata.updateSignerRegistrationName(
          walletId: source.id,
          signerId: signerId,
          registrationName: 'My hardware policy',
        ),
        isTrue,
      );
      expect(changes, 1);
      expect(
        await metadata.updateSignerRegistrationName(
          walletId: source.id,
          signerId: 'not-present',
          registrationName: 'Other',
        ),
        isFalse,
      );
      expect(changes, 1);
    },
  );

  test(
    'birthday comparison uses the persisted instant and precision',
    () async {
      final birthday = DateTime.utc(2026, 9, 9, 12, 0, 0, 123);
      final source = (await importSource()).copyWith(birthday: birthday);
      await metadata.store(source);
      var changes = 0;
      final subscription = metadata.catalogChanges.listen((_) => changes++);
      addTearDown(subscription.cancel);

      // Drift stores these timestamps as whole Unix seconds. Neither timezone
      // notation nor subsecond precision changes the persisted definition.
      await metadata.store(source.copyWith(birthday: birthday.toLocal()));
      expect(changes, 0);
      await metadata.store(
        source.copyWith(birthday: birthday.add(const Duration(seconds: 1))),
      );
      expect(changes, 1);
      await metadata.store(source.copyWith(birthday: null));
      expect(changes, 2);
    },
  );

  test('hides a passphrase wallet until its session is unlocked', () async {
    final source = await importSource(
      provenance: WalletProvenance.defaultSeedPassphrase,
    );

    expect(await wallets.getWallet(source.id), isNull);
    expect(await wallets.getWallets(), isEmpty);
    expect(await wallets.getStoredWalletIds(), {source.id});
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
