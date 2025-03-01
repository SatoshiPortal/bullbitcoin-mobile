import 'package:bb_mobile/_pkg/consts/config.dart';
import 'package:bb_mobile/core/data/datasources/pdk_data_source.dart';
import 'package:bb_mobile/core/data/datasources/seed_data_source.dart';
import 'package:bb_mobile/core/data/datasources/wallet_metadata_data_source.dart';
import 'package:bb_mobile/core/data/datasources/wallets/impl/bdk_wallet_data_source_impl.dart';
import 'package:bb_mobile/core/data/datasources/wallets/impl/lwk_wallet_data_source_impl.dart';
import 'package:bb_mobile/core/data/datasources/wallets/wallet_data_source.dart';
import 'package:bb_mobile/core/data/models/address_model.dart';
import 'package:bb_mobile/core/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/domain/entities/address.dart';
import 'package:bb_mobile/core/domain/entities/balance.dart';
import 'package:bb_mobile/core/domain/entities/payjoin.dart';
import 'package:bb_mobile/core/domain/entities/seed.dart';
import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/entities/wallet.dart';
import 'package:bb_mobile/core/domain/repositories/wallet_manager_repository.dart';
import 'package:path_provider/path_provider.dart';

class WalletManagerRepositoryImpl implements WalletManagerRepository {
  final WalletMetadataDataSource _walletMetadata;
  final SeedDataSource _seed;
  final PdkDataSource _pdk;

  WalletManagerRepositoryImpl({
    required WalletMetadataDataSource walletMetadataDataSource,
    required SeedDataSource seedDataSource,
    required PdkDataSource pdk,
  })  : _walletMetadata = walletMetadataDataSource,
        _seed = seedDataSource,
        _pdk = pdk;

  final Map<String, WalletDataSource> _wallets = {};

  @override
  Future<bool> doDefaultWalletsExist({required Environment environment}) async {
    final wallets = await _walletMetadata.getAll();

    final defaultWalletsOfEnvironment = wallets
        .where(
          (wallet) =>
              wallet.isDefault &&
              (wallet.isMainnet && environment.isMainnet ||
                  wallet.isTestnet && environment.isTestnet),
        )
        .toList();

    // Check if there are exactly 2 default wallets for the current environment
    if (defaultWalletsOfEnvironment.length != 2) {
      return false;
    }

    // Make sure that one is bitcoin and the other is liquid
    if (defaultWalletsOfEnvironment[0].isBitcoin !=
        defaultWalletsOfEnvironment[1].isLiquid) {
      return false;
    }

    // Make sure the wallets were created correctly and are usable
    for (final wallet in defaultWalletsOfEnvironment) {
      if (wallet.source != WalletSource.mnemonic.name) {
        return false;
      }
      final hasSeed = await _seed.exists(wallet.masterFingerprint);
      if (!hasSeed) {
        return false;
      }
    }

    return true;
  }

  @override
  Future<void> initExistingWallets() async {
    final walletsMetadata = await _walletMetadata.getAll();

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
    final metadata = await _walletMetadata.deriveFromSeed(
      seed: seed,
      network: network,
      scriptType: scriptType,
      label: label,
      isDefault: isDefault,
    );

    final wallet =
        await _createPublicWalletDataSource(walletMetadata: metadata);

    await _walletMetadata.store(metadata);

    await _registerWalletDataSource(id: metadata.id, wallet: wallet);

    // Fetch the balance (in the future maybe other details of the wallet too)
    final balance = await wallet.getBalance();
    //final lastTransactions = await wallet.getTransactions(offset: 0, limit: 3);

    // Return the created wallet entity
    return Wallet(
      id: metadata.id,
      label: metadata.label,
      network: network,
      balanceSat: balance.totalSat,
      isDefault: isDefault,
      //lastTransactions: lastTransactions,
      masterFingerprint: metadata.masterFingerprint,
      xpubFingerprint: metadata.xpubFingerprint,
      scriptType: scriptType,
      xpub: metadata.xpub,
      externalPublicDescriptor: metadata.externalPublicDescriptor,
      internalPublicDescriptor: metadata.internalPublicDescriptor,
      source: WalletSource.fromName(metadata.source),
    );
  }

  @override
  Future<Wallet> importWatchOnlyWallet({
    required String xpub,
    required Network network,
    required ScriptType scriptType,
    required String label,
  }) async {
    final metadata = await _walletMetadata.deriveFromXpub(
      xpub: xpub,
      network: network,
      scriptType: scriptType,
      label: label,
    );

    final wallet =
        await _createPublicWalletDataSource(walletMetadata: metadata);

    await _walletMetadata.store(metadata);

    await _registerWalletDataSource(id: metadata.id, wallet: wallet);

    // Fetch the balance (in the future maybe other details of the wallet too)
    final balance = await wallet.getBalance();

    // Return the created wallet entity
    return Wallet(
      id: metadata.id,
      label: metadata.label,
      network: network,
      balanceSat: balance.totalSat,
      xpubFingerprint: metadata.xpubFingerprint,
      scriptType: scriptType,
      xpub: metadata.xpub,
      externalPublicDescriptor: metadata.externalPublicDescriptor,
      internalPublicDescriptor: metadata.internalPublicDescriptor,
      source: WalletSource.fromName(metadata.source),
    );
  }

  @override
  Future<List<Wallet>> getWallets({Environment? environment}) async {
    final wallets = <Wallet>[];
    for (final walletEntry in _wallets.entries) {
      final metadata = await _walletMetadata.get(walletEntry.key);

      if (metadata == null) {
        continue;
      }

      if (environment != null && metadata.isMainnet != environment.isMainnet) {
        continue;
      }

      final balance = await walletEntry.value.getBalance();

      wallets.add(
        Wallet(
          id: metadata.id,
          label: metadata.label,
          network: Network.fromEnvironment(
            isTestnet: metadata.isTestnet,
            isLiquid: metadata.isLiquid,
          ),
          balanceSat: balance.totalSat,
          isDefault: metadata.isDefault,
          masterFingerprint: metadata.masterFingerprint,
          xpubFingerprint: metadata.xpubFingerprint,
          scriptType: ScriptType.fromName(metadata.scriptType),
          xpub: metadata.xpub,
          externalPublicDescriptor: metadata.externalPublicDescriptor,
          internalPublicDescriptor: metadata.internalPublicDescriptor,
          source: WalletSource.fromName(metadata.source),
        ),
      );
    }

    return wallets;
  }

  @override
  Future<Address> getAddressByIndex({
    required String walletId,
    required int index,
  }) async {
    final wallet = _wallets[walletId];

    if (wallet == null) {
      throw WalletNotFoundException(walletId);
    }

    final model = await wallet.getAddressByIndex(index);
    final address = await _addressModelToEntity(model, wallet: wallet);

    return address;
  }

  @override
  Future<Balance> getBalance({required String walletId}) async {
    final wallet = _wallets[walletId];

    if (wallet == null) {
      throw WalletNotFoundException(walletId);
    }

    final model = await wallet.getBalance();

    return model.toEntity();
  }

  @override
  Future<Address> getLastUnusedAddress({required String walletId}) async {
    final wallet = _wallets[walletId];

    if (wallet == null) {
      throw WalletNotFoundException(walletId);
    }

    final model = await wallet.getLastUnusedAddress();

    final address = await _addressModelToEntity(model, wallet: wallet);

    return address;
  }

  @override
  Future<Address> getNewAddress({required String walletId}) async {
    final wallet = _wallets[walletId];

    if (wallet == null) {
      throw WalletNotFoundException(walletId);
    }

    final model = await wallet.getNewAddress();
    final address = await _addressModelToEntity(model, wallet: wallet);

    return address;
  }

  @override
  Future<Seed> getSeed({required String walletId}) async {
    final metadata = await _walletMetadata.get(walletId);

    if (metadata == null) {
      throw WalletNotFoundException(walletId);
    }

    final model = await _seed.get(metadata.masterFingerprint);
    final seed = model.toEntity();

    return seed;
  }

  @override
  Future<void> sync({required String walletId}) async {
    final wallet = _wallets[walletId];

    if (wallet == null) {
      throw WalletNotFoundException(walletId);
    }

    return wallet.sync();
  }

  @override
  Future<void> syncAll() async {
    for (final wallet in _wallets.values) {
      await wallet.sync();
    }
  }

  @override
  Future<Payjoin> receivePayjoin({required String walletId}) async {
    // TODO: implement receivePayjoin
    throw UnimplementedError();
  }

  @override
  Future<Payjoin> sendPayjoin({required String walletId}) async {
    // TODO: implement sendPayjoin
    throw UnimplementedError();
  }

  Future<WalletDataSource?> _getWalletWithPrivateKey(String id) async {
    final walletMetadata = await _walletMetadata.get(id);

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
    required WalletMetadataModel walletMetadata,
  }) async {
    final dbPath = await _getWalletDbPath(walletMetadata.id);
    // TODO: get the Electrum Server from the settings repository
    if (walletMetadata.isBitcoin) {
      return BdkWalletDataSourceImpl.public(
        externalDescriptor: walletMetadata.externalPublicDescriptor,
        internalDescriptor: walletMetadata.internalPublicDescriptor,
        isTestnet: walletMetadata.isTestnet,
        dbPath: dbPath,
        electrumServer: ElectrumServerModel(
          url: walletMetadata.isMainnet ? bbElectrumMain : bbElectrumTest,
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
        isTestnet: walletMetadata.isTestnet,
        electrumServer: ElectrumServerModel(
          url: walletMetadata.isMainnet
              ? bbLiquidElectrumUrl
              : bbLiquidElectrumTestUrl,
          stopGap: 20,
          retry: 5,
          timeout: 5,
          validateDomain: true,
        ),
      );
    }
  }

  Future<WalletDataSource> _createPrivateWalletDataSource({
    required WalletMetadataModel walletMetadata,
  }) async {
    final dbPath = await _getWalletDbPath(walletMetadata.id);
    final seed = await _seed.get(walletMetadata.masterFingerprint);

    if (seed is! MnemonicSeed) {
      throw WrongSeedTypeException(
        'Seed type is not MnemonicSeed: ${seed.runtimeType}',
      );
    }

    final mnemonic = seed.mnemonicWords.join(' ');

    // TODO: get the Electrum Server from the settings repository
    if (walletMetadata.isBitcoin) {
      return BdkWalletDataSourceImpl.private(
        scriptType: ScriptType.fromName(walletMetadata.scriptType),
        mnemonic: mnemonic,
        passphrase: seed.passphrase,
        isTestnet: walletMetadata.isTestnet,
        dbPath: dbPath,
        electrumServer: ElectrumServerModel(
          url: walletMetadata.isMainnet ? bbElectrumMain : bbElectrumTest,
          stopGap: 20,
          retry: 5,
          timeout: 5,
          validateDomain: true,
        ),
      );
    } else {
      return LwkWalletDataSourceImpl.private(
        mnemonic: mnemonic,
        dbPath: dbPath,
        isTestnet: walletMetadata.isTestnet,
        electrumServer: ElectrumServerModel(
          url: walletMetadata.isMainnet
              ? bbLiquidElectrumUrl
              : bbLiquidElectrumTestUrl,
          stopGap: 20,
          retry: 5,
          timeout: 5,
          validateDomain: true,
        ),
      );
    }
  }

  @override
  Future<List<Address>> getUsedReceiveAddresses({
    required String walletId,
    int? limit,
    int? offset,
  }) async {
    final wallet = _wallets[walletId];

    if (wallet == null) {
      throw WalletNotFoundException(walletId);
    }

    final lastUnusedAddress = await wallet.getLastUnusedAddress();
    final nrOfAddresses = limit ?? lastUnusedAddress.index ?? 0 - (offset ?? 0);

    final addresses = <Address>[];
    for (int i = offset ?? 0; i < nrOfAddresses; i++) {
      final address = await wallet.getAddressByIndex(i);

      final balanceSat = await wallet.getAddressBalanceSat(address.address);
      if (wallet is LwkWalletDataSourceImpl) {
        addresses.add(
          Address.liquid(
            index: address.index,
            standard: address.address,
            kind: AddressKind.external,
            state: AddressStatus.used,
            balanceSat: balanceSat,
          ),
        );
      } else {
        addresses.add(
          Address.bitcoin(
            index: address.index,
            address: address.address,
            kind: AddressKind.external,
            state: AddressStatus.used,
            balanceSat: balanceSat,
          ),
        );
      }
    }

    return addresses;
  }

  Future<Address> _addressModelToEntity(
    AddressModel model, {
    required WalletDataSource wallet,
    AddressKind kind = AddressKind.external,
  }) async {
    final isUsed = await wallet.isAddressUsed(model.address);
    final balanceSat = await wallet.getAddressBalanceSat(model.address);

    Address address;
    if (wallet is LwkWalletDataSourceImpl) {
      address = Address.liquid(
        index: model.index,
        standard: model.address,
        kind: kind,
        state: isUsed ? AddressStatus.used : AddressStatus.unused,
        balanceSat: balanceSat,
      );
    } else {
      address = Address.bitcoin(
        index: model.index,
        address: model.address,
        kind: kind,
        state: isUsed ? AddressStatus.used : AddressStatus.unused,
        balanceSat: balanceSat,
      );
    }

    return address;
  }
}

class WrongSeedTypeException implements Exception {
  final String message;

  WrongSeedTypeException(this.message);
}

class WalletNotFoundException implements Exception {
  final String message;

  const WalletNotFoundException(this.message);
}
