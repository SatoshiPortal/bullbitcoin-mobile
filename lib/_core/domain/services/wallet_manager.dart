import 'package:bb_mobile/_core/data/repositories/bdk_wallet_repository_impl.dart';
import 'package:bb_mobile/_core/data/repositories/lwk_wallet_repository_impl.dart';
import 'package:bb_mobile/_core/domain/entities/electrum_server.dart';
import 'package:bb_mobile/_core/domain/entities/seed.dart';
import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/wallet.dart';
import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/_core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_repository.dart';
import 'package:bb_mobile/_core/domain/services/wallet_metadata_derivator.dart';
import 'package:bb_mobile/_core/utils/config.dart'
    show
        bbElectrumMain,
        bbElectrumTest,
        bbLiquidElectrumTestUrl,
        bbLiquidElectrumUrl;

abstract class WalletManager {
  Future<bool> doDefaultWalletsExist();
  Future<void> initExistingWallets();
  Future<Wallet> createWallet({
    required Seed seed,
    required Network network,
    required ScriptType scriptType,
    String label,
    bool isDefault,
  });
  Future<Wallet> importWatchOnlyWallet({
    required String xpub,
    required Network network,
    required ScriptType scriptType,
    required String label,
  });
  WalletRepository? getRepository(String walletId);
  List<WalletRepository> getRepositories({Environment? environment});
  Future<WalletRepository?> getRepositoryWithPrivateKey(String walletId);
  Future<List<Wallet>> getWallets();
}

class WalletManagerImpl implements WalletManager {
  final WalletMetadataDerivator _walletMetadataDerivator;
  final WalletMetadataRepository _walletMetadataRepository;
  final SeedRepository _seedRepository;
  final SettingsRepository _settingsRepository;
  final Map<String, WalletRepository> _repositories = {};

  WalletManagerImpl({
    required WalletMetadataDerivator walletMetadataDerivator,
    required WalletMetadataRepository walletMetadataRepository,
    required SeedRepository seedRepository,
    required SettingsRepository settingsRepository,
  })  : _walletMetadataDerivator = walletMetadataDerivator,
        _walletMetadataRepository = walletMetadataRepository,
        _seedRepository = seedRepository,
        _settingsRepository = settingsRepository;

  @override
  Future<bool> doDefaultWalletsExist() async {
    final wallets = await _walletMetadataRepository.getAllWalletsMetadata();

    final environment = await _settingsRepository.getEnvironment();
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
      final hasSeed = await _seedRepository.hasSeed(wallet.masterFingerprint);
      if (!hasSeed) {
        return false;
      }
    }

    return true;
  }

  @override
  Future<void> initExistingWallets() async {
    final walletsMetadata =
        await _walletMetadataRepository.getAllWalletsMetadata();

    for (final metadata in walletsMetadata) {
      final repository =
          await _createPublicRepository(walletMetadata: metadata);
      await _registerRepository(repository);
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

    final repository = await _createPublicRepository(walletMetadata: metadata);

    await _walletMetadataRepository.storeWalletMetadata(metadata);

    await _registerRepository(repository);

    // Fetch the balance (in the future maybe other details of the wallet too)
    final balance = await repository.getBalance();

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

    final repository = await _createPublicRepository(walletMetadata: metadata);

    await _walletMetadataRepository.storeWalletMetadata(metadata);

    await _registerRepository(repository);

    // Fetch the balance (in the future maybe other details of the wallet too)
    final balance = await repository.getBalance();

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
  WalletRepository? getRepository(String id) {
    return _repositories[id];
  }

  @override
  List<WalletRepository> getRepositories({Environment? environment}) {
    if (environment == null) {
      // Return all wallets
      return _repositories.values.toList();
    } else if (environment == Environment.mainnet) {
      return _repositories.values
          .where((wallet) => wallet.network.isMainnet)
          .toList();
    } else {
      return _repositories.values
          .where((wallet) => wallet.network.isTestnet)
          .toList();
    }
  }

  @override
  Future<WalletRepository?> getRepositoryWithPrivateKey(String id) async {
    final walletMetadata =
        await _walletMetadataRepository.getWalletMetadata(id);

    if (walletMetadata == null) {
      return null;
    }

    return _createPrivateRepository(walletMetadata: walletMetadata);
  }

  @override
  Future<List<Wallet>> getWallets() async {
    // Only get wallets for the current environment
    final environment = await _settingsRepository.getEnvironment();
    final walletRepositories = getRepositories(environment: environment);

    final wallets = <Wallet>[];
    for (final walletRepository in walletRepositories) {
      final walletMetadata = await _walletMetadataRepository
          .getWalletMetadata(walletRepository.id);

      if (walletMetadata == null) {
        continue;
      }

      final balance = await walletRepository.getBalance();

      wallets.add(
        Wallet(
          id: walletRepository.id,
          name: walletMetadata.name,
          balanceSat: balance.totalSat,
          network: walletMetadata.network,
          isDefault: walletMetadata.isDefault,
        ),
      );
    }

    return wallets;
  }

  Future<void> _registerRepository(WalletRepository repository) async {
    final id = repository.id;

    if (_repositories.containsKey(id)) {
      return;
    }

    _repositories[id] = repository;
  }

  Future<WalletRepository> _createPublicRepository({
    required WalletMetadata walletMetadata,
  }) async {
    final network = walletMetadata.network;
    // TODO: get the Electrum Server from the settings repository
    if (network.isBitcoin) {
      return BdkWalletRepositoryImpl.public(
        walletMetadata: walletMetadata,
        electrumServer: ElectrumServer(
          url: network.isMainnet ? bbElectrumMain : bbElectrumTest,
          network: network,
        ),
      );
    } else {
      return LwkWalletRepositoryImpl.public(
        walletMetadata: walletMetadata,
        electrumServer: ElectrumServer(
          url:
              network.isMainnet ? bbLiquidElectrumUrl : bbLiquidElectrumTestUrl,
          network: walletMetadata.network,
        ),
      );
    }
  }

  Future<WalletRepository> _createPrivateRepository({
    required WalletMetadata walletMetadata,
  }) async {
    final network = walletMetadata.network;
    final seed =
        await _seedRepository.getSeed(walletMetadata.masterFingerprint);

    if (seed is! MnemonicSeed) {
      throw WrongSeedTypeException(
        'Seed type is not MnemonicSeed: ${seed.runtimeType}',
      );
    }

    // TODO: get the Electrum Server from the settings repository
    if (network.isBitcoin) {
      return BdkWalletRepositoryImpl.private(
        walletMetadata: walletMetadata,
        electrumServer: ElectrumServer(
          url: network.isMainnet ? bbElectrumMain : bbElectrumTest,
          network: network,
        ),
        mnemonicSeed: seed,
      );
    } else {
      return LwkWalletRepositoryImpl.private(
        walletMetadata: walletMetadata,
        electrumServer: ElectrumServer(
          url:
              network.isMainnet ? bbLiquidElectrumUrl : bbLiquidElectrumTestUrl,
          network: walletMetadata.network,
        ),
        mnemonicSeed: seed,
      );
    }
  }
}

class WrongSeedTypeException implements Exception {
  final String message;

  WrongSeedTypeException(this.message);
}
