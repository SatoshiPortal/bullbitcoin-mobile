import 'package:bb_mobile/core/domain/entities/seed.dart';
import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/core/domain/services/wallet_derivation_service.dart';
import 'package:bb_mobile/core/domain/services/wallet_repository_manager.dart';
import 'package:bb_mobile/features/onboarding/domain/services/mnemonic_generator.dart';

class CreateDefaultWalletsUseCase {
  final SettingsRepository _settingsRepository;
  final MnemonicGenerator _mnemonicGenerator;
  final SeedRepository _seedRepository;
  final WalletDerivationService _walletDerivationservice;
  final WalletMetadataRepository _walletMetadataRepository;
  final WalletRepositoryManager _walletRepositoryManager;

  CreateDefaultWalletsUseCase({
    required SettingsRepository settingsRepository,
    required MnemonicGenerator mnemonicGenerator,
    required SeedRepository seedRepository,
    required WalletDerivationService walletDerivationService,
    required WalletMetadataRepository walletMetadataRepository,
    required WalletRepositoryManager walletRepositoryManager,
  })  : _settingsRepository = settingsRepository,
        _mnemonicGenerator = mnemonicGenerator,
        _seedRepository = seedRepository,
        _walletDerivationservice = walletDerivationService,
        _walletMetadataRepository = walletMetadataRepository,
        _walletRepositoryManager = walletRepositoryManager;

  Future<void> execute() async {
    final environment = await _settingsRepository.getEnvironment();
    final mnemonicSeed = await _generateMnemonicSeed();

    // Get the default wallets metadata for Bitcoin and Liquid
    final defaultWalletsMetadata = await Future.wait([
      _deriveBitcoinWalletMetadata(
          seed: mnemonicSeed, environment: environment),
      _deriveLiquidWalletMetadata(seed: mnemonicSeed, environment: environment),
    ]);

    // Store the seed, default wallets metadata and register them in the wallet repository manager
    await Future.wait([
      _seedRepository.storeSeed(mnemonicSeed),
      _walletMetadataRepository.storeWalletMetadata(defaultWalletsMetadata[0]),
      _walletMetadataRepository.storeWalletMetadata(defaultWalletsMetadata[1]),
      _walletRepositoryManager.registerWallet(defaultWalletsMetadata[0]),
      _walletRepositoryManager.registerWallet(defaultWalletsMetadata[1]),
    ]);
  }

  Future<MnemonicSeed> _generateMnemonicSeed() async {
    final mnemonic = await _mnemonicGenerator.newMnemonic;

    return MnemonicSeed(
      mnemonicWords: mnemonic,
    );
  }

  Future<WalletMetadata> _deriveBitcoinWalletMetadata({
    required MnemonicSeed seed,
    required Environment environment,
  }) async {
    final network = environment == Environment.mainnet
        ? Network.bitcoinMainnet
        : Network.bitcoinTestnet;
    // Use bip84 as the default script type for Bitcoin
    const scriptType = ScriptType.bip84;
    final xpub = await _walletDerivationservice.getAccountXpub(
      seed,
      network: network,
      scriptType: scriptType,
    );

    final descriptors = await Future.wait([
      _walletDerivationservice.derivePublicDescriptor(
        seed,
        network: network,
        scriptType: scriptType,
      ),
      _walletDerivationservice.derivePublicChangeDescriptor(
        seed,
        network: network,
        scriptType: scriptType,
      ),
    ]);

    return WalletMetadata(
      masterFingerprint: seed.masterFingerprint,
      source: WalletSource.mnemonic,
      network: network,
      scriptType: scriptType,
      xpub: xpub,
      externalPublicDescriptor: descriptors[0],
      internalPublicDescriptor: descriptors[1],
      isDefault: true,
    );
  }

  Future<WalletMetadata> _deriveLiquidWalletMetadata({
    required MnemonicSeed seed,
    required Environment environment,
  }) async {
    final network = environment == Environment.mainnet
        ? Network.liquidMainnet
        : Network.liquidTestnet;
    // Use bip84 as the default script type for Liquid
    const scriptType = ScriptType.bip84;
    final xpub = await _walletDerivationservice.getAccountXpub(
      seed,
      network: network,
      scriptType: scriptType,
    );

    final descriptor = await _walletDerivationservice.derivePublicDescriptor(
      seed,
      network: network,
      scriptType: scriptType,
    );

    return WalletMetadata(
      masterFingerprint: seed.masterFingerprint,
      source: WalletSource.mnemonic,
      network: network,
      scriptType: scriptType,
      xpub: xpub,
      externalPublicDescriptor: descriptor,
      internalPublicDescriptor: descriptor,
      isDefault: true,
    );
  }
}
