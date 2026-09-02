// End-to-end proof of the private-session boundary (spec F13, 20.2, 20.6).
//
// The four consumers that used to read WalletUnlockSession directly — Bitcoin
// signing, address generation, wallet storage/visibility and Payjoin — are
// wired here over ONE resolver, which is the point: locking is a single fact,
// not four checks each of them has to remember to make. Unlock, prove all four
// work; lock, prove all four refuse.
import 'dart:typed_data';

import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/payjoin_wallet_adapter.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/wallet_signing_material_resolver.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_unlock_session.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_private_wallet_session_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_public_projection_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/lock_private_wallet_session_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/mount_wallet_with_private_capability_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/update_wallet_label_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_visible_wallet_catalog_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;

class _Bdk extends Mock implements BdkWalletDatasource {}

class _Lwk extends Mock implements LwkWalletDatasource {}

class _Servers extends Mock implements ElectrumServersPort {}

class _Seeds extends Mock implements SeedDatasource {}

class _Labels extends Mock implements LabelsFacade {}

class _Frozen extends Mock implements FrozenWalletUtxoDatasource {}

class _Settings extends Mock implements SettingsRepository {}

// Obviously-fake fixtures: the all-zero BIP39 test vector and a joke passphrase.
const _mnemonic = ['abandon', 'ability', 'about'];
const _passphrase = 'hunter2';

// Encodes as a bitcoin testnet BIP84 origin so isBitcoin decodes to true.
const _walletId = 'wpkh([73c5da0a/84h/1h/0h])';

const _passphraseMetadata = WalletMetadataModel(
  id: _walletId,
  masterFingerprint: '73c5da0a',
  xpubFingerprint: 'deadbeef',
  isEncryptedVaultTested: false,
  isPhysicalBackupTested: false,
  xpub: 'tpub-test',
  externalPublicDescriptor: 'wpkh(external)',
  internalPublicDescriptor: 'wpkh(internal)',
  signer: Signer.local,
  isDefault: false,
  provenance: WalletProvenance.defaultSeedPassphrase,
);

MnemonicSeed _seed() =>
    Seed.mnemonic(
          mnemonicWords: _mnemonic,
          passphrase: _passphrase,
          bytes: Uint8List.fromList([1, 2, 3]),
          masterFingerprint: '73c5da0a',
        )
        as MnemonicSeed;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WalletUnlockSession session;
  late WalletSigningMaterialResolver signingMaterial;
  late _Bdk bdk;
  late _Seeds seeds;
  late _Labels labels;

  late BitcoinWalletRepository bitcoin;
  late WalletAddressRepository addresses;
  late PayjoinWalletAdapter payjoin;
  late WalletMetadataDatasource metadataStore;
  late WalletRepository wallets;
  late WalletFacade facade;

  setUpAll(() {
    registerFallbackValue(
      const WalletModel.publicBdk(
        id: _walletId,
        externalDescriptor: 'wpkh(external)',
        internalDescriptor: 'wpkh(internal)',
        isTestnet: true,
      ),
    );
    registerFallbackValue(
      const WalletModel.privateBdk(
            id: 'fallback',
            scriptType: ScriptType.bip84,
            mnemonic: 'abandon',
            isTestnet: true,
          )
          as PrivateBdkWalletModel,
    );
  });

  setUp(() {
    session = WalletUnlockSession();
    seeds = _Seeds();
    bdk = _Bdk();
    signingMaterial = WalletSigningMaterialResolver(
      seedDatasource: seeds,
      session: session,
    );
    addTearDown(session.close);

    final metadataDatasource = _MetadataStub();
    labels = _Labels();
    bitcoin = BitcoinWalletRepository(
      walletMetadataDatasource: metadataDatasource,
      bdkWalletDatasource: bdk,
      frozenWalletUtxoDatasource: _Frozen(),
      signingMaterialResolver: signingMaterial,
    );
    addresses = WalletAddressRepository(
      walletMetadataDatasource: metadataDatasource,
      bdkWalletDatasource: bdk,
      lwkWalletDatasource: _Lwk(),
      labelsFacade: labels,
      signingMaterialResolver: signingMaterial,
    );
    payjoin = PayjoinWalletAdapter(bdk, metadataDatasource, signingMaterial);

    when(
      () => bdk.signPsbt(any(), wallet: any(named: 'wallet')),
    ).thenAnswer((_) async => 'signed');
    when(
      () => bdk.getAddressByIndex(
        any(),
        wallet: any(named: 'wallet'),
        isChange: any(named: 'isChange'),
      ),
    ).thenAnswer((_) async => 'tb1qreceive');
    when(() => labels.fetchByReference(any())).thenAnswer((_) async => []);
    when(
      () => bdk.delete(wallet: any(named: 'wallet')),
    ).thenAnswer((_) async {});
  });

  group('after lock, no consumer can resolve private material', () {
    setUp(() {
      signingMaterial.loadPrivateCapabilityIfCurrent(
        generation: signingMaterial.beginPrivateCapabilityMount(),
        walletId: _walletId,
        seed: _seed(),
      );
    });

    test('bitcoin signing', () async {
      expect(await bitcoin.signPsbt('unsigned', walletId: _walletId), 'signed');

      signingMaterial.clearPrivateCapabilityForBackground();

      await expectLater(
        bitcoin.signPsbt('unsigned', walletId: _walletId),
        throwsA(isA<PassphraseWalletLockedException>()),
      );
      // The persistent seed store is never consulted for a passphrase wallet,
      // locked or not.
      verifyNever(() => seeds.get(any()));
    });

    test('address generation', () async {
      expect(
        (await addresses.getAddressAtIndex(
          walletId: _walletId,
          index: 0,
          isChange: false,
        )).address,
        'tb1qreceive',
      );

      signingMaterial.clearPrivateCapabilityForBackground();

      await expectLater(
        addresses.getAddressAtIndex(
          walletId: _walletId,
          index: 0,
          isChange: false,
        ),
        throwsA(isA<PassphraseWalletLockedException>()),
      );
    });

    test('payjoin signing', () async {
      expect(
        await payjoin.signPsbt(
          walletId: _walletId,
          network: BitcoinNetwork.testnet,
          psbt: 'unsigned',
        ),
        'signed',
      );

      signingMaterial.clearPrivateCapabilityForBackground();

      await expectLater(
        payjoin.signPsbt(
          walletId: _walletId,
          network: BitcoinNetwork.testnet,
          psbt: 'unsigned',
        ),
        throwsA(isA<PassphraseWalletLockedException>()),
      );
      verifyNever(() => seeds.get(any()));
    });
  });

  group('visible catalog', () {
    late SqliteDatabase database;
    late String mountedId;

    setUp(() async {
      database = SqliteDatabase(NativeDatabase.memory());
      metadataStore = WalletMetadataDatasource(sqlite: database);
      addTearDown(database.close);

      final lwk = _Lwk();
      when(
        () => bdk.walletSyncFinishedStream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => lwk.walletSyncFinishedStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => bdk.getBalance(wallet: any(named: 'wallet'))).thenAnswer(
        (_) async => BalanceModel(
          immatureSat: BigInt.zero,
          trustedPendingSat: BigInt.zero,
          untrustedPendingSat: BigInt.zero,
          confirmedSat: BigInt.zero,
          spendableSat: BigInt.zero,
          totalSat: BigInt.zero,
        ),
      );

      wallets = WalletRepository(
        walletMetadataDatasource: metadataStore,
        bdkWalletDatasource: bdk,
        lwkWalletDatasource: lwk,
        serversPort: _Servers(),
        signingMaterialResolver: signingMaterial,
      );

      final settings = _Settings();
      when(settings.fetch).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.testnet,
          bitcoinUnit: BitcoinUnit.btc,
          currencyCode: 'CAD',
        ),
      );

      facade = WalletFacade(
        MountWalletWithPrivateCapabilityUsecase(wallets, signingMaterial),
        LockPrivateWalletSessionUsecase(signingMaterial),
        CheckPrivateWalletSessionUsecase(signingMaterial),
        WatchVisibleWalletCatalogUsecase(wallets, settings, signingMaterial),
        DeleteWalletPublicProjectionUsecase(wallets, signingMaterial),
        UpdateWalletLabelUsecase(wallets),
      );

      // The projection a passphrase wallet leaves behind: present in storage,
      // visible only while its session is loaded.
      await metadataStore.store(_passphraseMetadata);
      mountedId = _passphraseMetadata.id;
    });

    test('drops the wallet on lock and emits the new catalog', () async {
      signingMaterial.loadPrivateCapabilityIfCurrent(
        generation: signingMaterial.beginPrivateCapabilityMount(),
        walletId: mountedId,
        seed: _seed(),
      );
      expect(facade.isPrivateWalletSessionLoaded(mountedId), isTrue);
      expect(
        (await wallets.getWallets()).map((wallet) => wallet.id),
        contains(mountedId),
      );

      final published = facade.watchVisibleWalletCatalog();
      final next = published.first;

      expect(facade.lockPrivateWalletSession(), isTrue);

      expect(
        (await next).map((wallet) => wallet.id),
        isNot(contains(mountedId)),
      );
      expect(facade.isPrivateWalletSessionLoaded(mountedId), isFalse);
      // The public projection stays in storage for a cheap remount (spec 20.2).
      expect(await metadataStore.fetch(mountedId), isNotNull);
    });

    test(
      'deletePublicProjection clears the capability and the cache',
      () async {
        signingMaterial.loadPrivateCapabilityIfCurrent(
          generation: signingMaterial.beginPrivateCapabilityMount(),
          walletId: mountedId,
          seed: _seed(),
        );

        await facade.deletePublicProjection(mountedId);

        expect(facade.isPrivateWalletSessionLoaded(mountedId), isFalse);
        expect(await metadataStore.fetch(mountedId), isNull);
      },
    );
  });
}

/// Serves the one passphrase wallet the signing paths ask about.
class _MetadataStub extends Mock implements WalletMetadataDatasource {
  @override
  Future<WalletMetadataModel?> fetch(String walletId) async =>
      walletId == _walletId ? _passphraseMetadata : null;
}
