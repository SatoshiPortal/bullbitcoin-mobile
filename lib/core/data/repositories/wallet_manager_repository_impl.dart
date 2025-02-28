import 'dart:convert';

import 'package:bb_mobile/_pkg/consts/config.dart'
    show
        bbElectrumMain,
        bbElectrumTest,
        bbLiquidElectrumTestUrl,
        bbLiquidElectrumUrl;
import 'package:bb_mobile/core/data/datasources/key_value_storage/key_value_storage_data_source.dart';
import 'package:bb_mobile/core/data/datasources/pdk_data_source.dart';
import 'package:bb_mobile/core/data/datasources/wallet/impl/bdk_wallet_data_source_impl.dart';
import 'package:bb_mobile/core/data/datasources/wallet/impl/lwk_wallet_data_source_impl.dart';
import 'package:bb_mobile/core/data/datasources/wallet/wallet_data_source.dart';
import 'package:bb_mobile/core/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/data/models/seed_model.dart';
import 'package:bb_mobile/core/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/domain/entities/address.dart';
import 'package:bb_mobile/core/domain/entities/balance.dart';
import 'package:bb_mobile/core/domain/entities/payjoin.dart';
import 'package:bb_mobile/core/domain/entities/seed.dart';
import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/entities/wallet.dart';
import 'package:bb_mobile/core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/core/domain/repositories/wallet_manager_repository.dart';
import 'package:bb_mobile/core/domain/services/wallet_metadata_derivator.dart';
import 'package:bb_mobile/utils/constants.dart';
import 'package:path_provider/path_provider.dart';

class WalletManagerRepositoryImpl implements WalletManagerRepository {
  final WalletMetadataDerivator _walletMetadataDerivator;
  final KeyValueStorageDataSource<String> _secureStorage;
  final KeyValueStorageDataSource<String> _walletMetadataStorage;
  final PdkDataSource _pdk;
  final Map<String, WalletDataSource> _wallets = {};

  WalletManagerRepositoryImpl({
    required WalletMetadataDerivator walletMetadataDerivator,
    required KeyValueStorageDataSource<String> secureStorage,
    required KeyValueStorageDataSource<String> walletMetadataStorage,
    required PdkDataSource pdk,
  })  : _walletMetadataDerivator = walletMetadataDerivator,
        _secureStorage = secureStorage,
        _walletMetadataStorage = walletMetadataStorage,
        _pdk = pdk;

  @override
  Future<bool> doDefaultWalletsExist({Environment? environment}) async {
    final wallets = await _getAllWalletsMetadata();

    final defaultWalletsOfEnvironment = wallets
        .where(
          (wallet) =>
              wallet.isDefault &&
              (wallet.network.isMainnet && Environment.mainnet == environment ||
                  wallet.network.isTestnet &&
                      Environment.testnet == environment),
        )
        .toList();

    // Check if there are exactly 2 default wallets for the current environment
    if (defaultWalletsOfEnvironment.length != 2) {
      return false;
    }

    // Make sure that one is bitcoin and the other is liquid
    if (defaultWalletsOfEnvironment[0].network.isBitcoin !=
        defaultWalletsOfEnvironment[1].network.isLiquid) {
      return false;
    }

    // Make sure the wallets were created correctly and are usable
    for (final wallet in defaultWalletsOfEnvironment) {
      if (wallet.source != WalletSource.mnemonic) {
        return false;
      }
      final hasSeed = await _hasSeed(wallet.masterFingerprint);
      if (!hasSeed) {
        return false;
      }
    }

    return true;
  }

  @override
  Future<void> initExistingWallets() async {
    final walletsMetadata = await _getAllWalletsMetadata();

    for (final metadata in walletsMetadata) {
      final wallet =
          await _createPublicWalletDataSource(walletMetadata: metadata);
      await _registerWalletDataSource(id: metadata.id, wallet: wallet);
    }
  }

  @override
  Future<Wallet> createWallet({
    required Seed seed,
    required Network network,
    required ScriptType scriptType,
    String label = '',
    bool isDefault = false,
  }) async {
    final metadata = await _walletMetadataDerivator.fromSeed(
      seed: seed,
      network: network,
      scriptType: scriptType,
      label: label,
      isDefault: isDefault,
    );

    final wallet =
        await _createPublicWalletDataSource(walletMetadata: metadata);

    await _storeWalletMetadata(metadata);

    await _registerWalletDataSource(id: metadata.id, wallet: wallet);

    // Fetch the balance (in the future maybe other details of the wallet too)
    final balance = await wallet.getBalance();

    // Return the created wallet entity
    return Wallet(
      id: metadata.id,
      name: metadata.name,
      balanceSat: balance.totalSat,
      network: network,
      isDefault: isDefault,
    );
  }

  @override
  Future<Wallet> importWatchOnlyWallet({
    required String xpub,
    required Network network,
    required ScriptType scriptType,
    required String label,
  }) async {
    final metadata = await _walletMetadataDerivator.fromXpub(
      xpub: xpub,
      network: network,
      scriptType: scriptType,
      label: label,
    );

    final wallet =
        await _createPublicWalletDataSource(walletMetadata: metadata);

    await _storeWalletMetadata(metadata);

    await _registerWalletDataSource(id: metadata.id, wallet: wallet);

    // Fetch the balance (in the future maybe other details of the wallet too)
    final balance = await wallet.getBalance();

    // Return the created wallet entity
    return Wallet(
      id: metadata.id,
      name: metadata.name,
      balanceSat: balance.totalSat,
      network: network,
      isDefault: false,
    );
  }

  @override
  Future<List<Wallet>> getWallets({Environment? environment}) async {
    final wallets = <Wallet>[];
    for (final walletId in _wallets.keys) {
      final walletMetadata = await _getWalletMetadata(walletId);

      if (walletMetadata == null) {
        continue;
      }

      if (environment != null &&
          walletMetadata.network.isMainnet != environment.isMainnet) {
        continue;
      }

      final balance = await _wallets[walletId]?.getBalance();

      wallets.add(
        Wallet(
          id: walletId,
          name: walletMetadata.name,
          balanceSat: balance?.totalSat ?? BigInt.zero,
          network: walletMetadata.network,
          isDefault: walletMetadata.isDefault,
        ),
      );
    }

    return wallets;
  }

  @override
  Future<Address> getAddressByIndex(
      {required String walletId, required int index}) async {
    final wallet = _wallets[walletId];

    if (wallet == null) {
      throw WalletNotFoundException(walletId);
    }

    final model = await wallet.getAddressByIndex(index);
    // TODO: Here we can look up if the address has any label and add it to the entity

    final address = Address(
      index: model.index,
      address: model.address,
      scriptType: model.scriptType,
      network: model.network,
      isChange: model.isChange,
      isUsed: model.isUsed,
    );
    return address;
  }

  @override
  Future<Balance> getBalance({required String walletId}) {
    // TODO: implement getBalance
    throw UnimplementedError();
  }

  @override
  Future<Address> getLastUnusedAddress({required String walletId}) {
    // TODO: implement getLastUnusedAddress
    throw UnimplementedError();
  }

  @override
  Future<Address> getNewAddress({required String walletId}) {
    // TODO: implement getNewAddress
    throw UnimplementedError();
  }

  @override
  Future<Seed> getSeed({required String walletId}) {
    // TODO: implement getSeed
    throw UnimplementedError();
  }

  @override
  Future<Payjoin> receivePayjoin({required String walletId}) {
    // TODO: implement receivePayjoin
    throw UnimplementedError();
  }

  @override
  Future<Payjoin> sendPayjoin({required String walletId}) {
    // TODO: implement sendPayjoin
    throw UnimplementedError();
  }

  @override
  Future<void> sync({required String walletId}) {
    // TODO: implement sync
    throw UnimplementedError();
  }

  @override
  Future<void> syncAll() {
    // TODO: implement syncAll
    throw UnimplementedError();
  }

  Future<WalletDataSource?> _getWalletWithPrivateKey(String id) async {
    final walletMetadata = await _getWalletMetadata(id);

    if (walletMetadata == null) {
      return null;
    }

    return _createPrivateWalletDataSource(walletMetadata: walletMetadata);
  }

  Future<void> _registerWalletDataSource({
    required String id,
    required WalletDataSource wallet,
  }) async {
    if (_wallets.containsKey(id)) {
      return;
    }

    _wallets[id] = wallet;
  }

  Future<String> _getWalletDbPath(String walletId) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$walletId';
  }

  Future<WalletDataSource> _createPublicWalletDataSource({
    required WalletMetadata walletMetadata,
  }) async {
    final network = walletMetadata.network;
    final dbPath = await _getWalletDbPath(walletMetadata.id);
    // TODO: get the Electrum Server from the settings repository
    if (network.isBitcoin) {
      return BdkWalletDataSourceImpl.public(
        externalDescriptor: walletMetadata.externalPublicDescriptor,
        internalDescriptor: walletMetadata.internalPublicDescriptor,
        isTestnet: network.isTestnet,
        dbPath: dbPath,
        electrumServer: ElectrumServerModel(
          url: network.isMainnet ? bbElectrumMain : bbElectrumTest,
          stopGap: 20,
          retry: 5,
          timeout: 5,
          validateDomain: true,
        ),
      );
    } else {
      return LwkWalletDataSourceImpl.public(
        ctDescriptor: walletMetadata.externalPublicDescriptor,
        dbPath: dbPath,
        isTestnet: network.isTestnet,
        electrumServer: ElectrumServerModel(
          url:
              network.isMainnet ? bbLiquidElectrumUrl : bbLiquidElectrumTestUrl,
          stopGap: 20,
          retry: 5,
          timeout: 5,
          validateDomain: true,
        ),
      );
    }
  }

  Future<WalletDataSource> _createPrivateWalletDataSource({
    required WalletMetadata walletMetadata,
  }) async {
    final network = walletMetadata.network;
    final dbPath = await _getWalletDbPath(walletMetadata.id);
    final seed = await _getSeed(walletMetadata.masterFingerprint);

    if (seed is! MnemonicSeed) {
      throw WrongSeedTypeException(
        'Seed type is not MnemonicSeed: ${seed.runtimeType}',
      );
    }

    // TODO: get the Electrum Server from the settings repository
    if (network.isBitcoin) {
      return BdkWalletDataSourceImpl.private(
        scriptType: walletMetadata.scriptType,
        mnemonicSeed: seed,
        isTestnet: network.isTestnet,
        dbPath: dbPath,
        electrumServer: ElectrumServerModel(
          url: network.isMainnet ? bbElectrumMain : bbElectrumTest,
          stopGap: 20,
          retry: 5,
          timeout: 5,
          validateDomain: true,
        ),
      );
    } else {
      return LwkWalletDataSourceImpl.private(
        mnemonicSeed: seed,
        dbPath: dbPath,
        isTestnet: network.isTestnet,
        electrumServer: ElectrumServerModel(
          url:
              network.isMainnet ? bbLiquidElectrumUrl : bbLiquidElectrumTestUrl,
          stopGap: 20,
          retry: 5,
          timeout: 5,
          validateDomain: true,
        ),
      );
    }
  }

  Future<void> _storeWalletMetadata(WalletMetadata metadata) async {
    final model = WalletMetadataModel.fromEntity(metadata);
    final value = jsonEncode(model.toJson());
    await _walletMetadataStorage.saveValue(key: metadata.id, value: value);
  }

  Future<WalletMetadata?> _getWalletMetadata(String walletId) async {
    final value = await _walletMetadataStorage.getValue(walletId);

    if (value == null) {
      return null;
    }

    final json = jsonDecode(value) as Map<String, dynamic>;
    final model = WalletMetadataModel.fromJson(json);
    final metadata = model.toEntity();

    return metadata;
  }

  Future<List<WalletMetadata>> _getAllWalletsMetadata() async {
    final map = await _walletMetadataStorage.getAll();

    return map.values
        .map((value) => jsonDecode(value) as Map<String, dynamic>)
        .map((json) => WalletMetadataModel.fromJson(json).toEntity())
        .toList();
  }

  Future<void> _deleteWalletMetadata(String walletId) {
    return _walletMetadataStorage.deleteValue(walletId);
  }

  Future<void> _storeSeed(Seed seed) {
    final key = _seedKey(seed.masterFingerprint);
    final model = SeedModel.fromEntity(seed);
    final value = jsonEncode(model.toJson());
    return _secureStorage.saveValue(key: key, value: value);
  }

  Future<Seed> _getSeed(String fingerprint) async {
    final key = _seedKey(fingerprint);
    final value = await _secureStorage.getValue(key);
    if (value == null) {
      throw SeedNotFoundException(
        'Seed not found for fingerprint: $fingerprint',
      );
    }

    final json = jsonDecode(value) as Map<String, dynamic>;
    final model = SeedModel.fromJson(json);
    final seed = model.toEntity();

    return seed;
  }

  Future<bool> _hasSeed(String fingerprint) {
    final key = _seedKey(fingerprint);
    return _secureStorage.hasValue(key);
  }

  Future<void> _deleteSeed(String fingerprint) {
    final key = _seedKey(fingerprint);
    return _secureStorage.deleteValue(key);
  }

  String _seedKey(String fingerprint) =>
      '${StorageConstants.seedKeyPrefix}$fingerprint';
}

class WrongSeedTypeException implements Exception {
  final String message;

  WrongSeedTypeException(this.message);
}

class SeedNotFoundException implements Exception {
  final String message;

  const SeedNotFoundException(this.message);
}

class WalletNotFoundException implements Exception {
  final String message;

  const WalletNotFoundException(this.message);
}
