import 'package:bb_mobile/features/wallet/domain/entities/seed.dart';
import 'package:bb_mobile/features/wallet/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/features/wallet/domain/services/mnemonic_generator.dart';
import 'package:bb_mobile/features/wallet/domain/services/wallet_derivation_service.dart';
import 'package:bb_mobile/features/wallet/domain/services/wallet_repository_manager.dart';

class CreateDefaultWalletsUseCase {
  // TODO: final NetworkEnvironmentRepository _networkEnvironmentRepository;
  final MnemonicGenerator _mnemonicGenerator;
  final SeedRepository _seedRepository;
  final WalletDerivationService _walletDerivationservice;
  final WalletMetadataRepository _walletMetadataRepository;
  final WalletRepositoryManager _walletRepositoryManager;

  CreateDefaultWalletsUseCase({
    required MnemonicGenerator mnemonicGenerator,
    required SeedRepository seedRepository,
    required WalletDerivationService walletDerivationService,
    required WalletMetadataRepository walletMetadataRepository,
    required WalletRepositoryManager walletRepositoryManager,
  })  : _mnemonicGenerator = mnemonicGenerator,
        _seedRepository = seedRepository,
        _walletDerivationservice = walletDerivationService,
        _walletMetadataRepository = walletMetadataRepository,
        _walletRepositoryManager = walletRepositoryManager;

  Future<void> execute() async {
    final mnemonicSeed = await _generateMnemonicSeed();
    await _seedRepository.storeSeed(mnemonicSeed);

    // Get the default wallets metadata for Bitcoin and Liquid
    final defaultWalletsMetadata = await Future.wait([
      _deriveBitcoinWalletMetadata(seed: mnemonicSeed),
      _deriveLiquidWalletMetadata(seed: mnemonicSeed),
    ]);

    // Store the default wallets metadata and register them in the wallet repository manager
    await Future.wait([
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
    Network network = Network.bitcoinMainnet,
    ScriptType scriptType = ScriptType.bip84,
  }) async {
    final xpub = await _walletDerivationservice.getAccountXpub(seed);

    final descriptors = await Future.wait([
      _walletDerivationservice.derivePublicDescriptor(seed,
          network: network, scriptType: scriptType),
      _walletDerivationservice.derivePublicChangeDescriptor(seed,
          network: network, scriptType: scriptType),
    ]);

    return WalletMetadata(
      masterFingerprint: seed.masterFingerprint,
      source: WalletSource.mnemonic,
      network: network,
      scriptType: scriptType,
      xpub: xpub,
      externalPublicDescriptor: descriptors[0],
      internalPublicDescriptor: descriptors[1],
    );
  }

  Future<WalletMetadata> _deriveLiquidWalletMetadata({
    required MnemonicSeed seed,
    Network network = Network.liquidMainnet,
    ScriptType scriptType = ScriptType.bip84,
  }) async {
    final xpub = await _walletDerivationservice.getAccountXpub(seed);

    final descriptor = await _walletDerivationservice
        .derivePublicDescriptor(seed, network: network, scriptType: scriptType);

    return WalletMetadata(
      masterFingerprint: seed.masterFingerprint,
      source: WalletSource.mnemonic,
      network: network,
      scriptType: scriptType,
      xpub: xpub,
      externalPublicDescriptor: descriptor,
      internalPublicDescriptor: descriptor,
    );
  }
}
