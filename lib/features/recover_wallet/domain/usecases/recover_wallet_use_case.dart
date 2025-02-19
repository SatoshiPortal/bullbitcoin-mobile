import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/core/domain/services/mnemonic_seed_factory.dart';
import 'package:bb_mobile/core/domain/services/wallet_metadata_derivation_service.dart';
import 'package:bb_mobile/core/domain/services/wallet_repository_manager.dart';

class RecoverWalletUseCase {
  final SettingsRepository _settingsRepository;
  final MnemonicSeedFactory _mnemonicSeedFactory;
  final SeedRepository _seedRepository;
  final WalletMetadataDerivationService _walletMetadataDerivationService;
  final WalletMetadataRepository _walletMetadataRepository;
  final WalletRepositoryManager _walletRepositoryManager;

  RecoverWalletUseCase({
    required SettingsRepository settingsRepository,
    required MnemonicSeedFactory mnemonicSeedFactory,
    required SeedRepository seedRepository,
    required WalletMetadataDerivationService walletMetadataDerivationService,
    required WalletMetadataRepository walletMetadataRepository,
    required WalletRepositoryManager walletRepositoryManager,
  })  : _settingsRepository = settingsRepository,
        _mnemonicSeedFactory = mnemonicSeedFactory,
        _seedRepository = seedRepository,
        _walletMetadataDerivationService = walletMetadataDerivationService,
        _walletMetadataRepository = walletMetadataRepository,
        _walletRepositoryManager = walletRepositoryManager;

  Future<void> execute({
    required List<String> mnemonicWords,
    String? passphrase,
    required ScriptType scriptType,
    String label = '',
  }) async {
    final environment = await _settingsRepository.getEnvironment();

    final mnemonicSeed = _mnemonicSeedFactory.fromWords(
      mnemonicWords,
      passphrase: passphrase,
    );

    final walletMetadata = await _walletMetadataDerivationService.fromSeed(
      seed: mnemonicSeed,
      network: environment == Environment.mainnet
          ? Network.bitcoinMainnet
          : Network.bitcoinTestnet,
      scriptType: scriptType,
      label: label,
    );

    // Store the seed and wallet metadata and
    //  register the wallet in the wallet repository manager so it can be used
    //  in the app.
    await Future.wait([
      _seedRepository.storeSeed(mnemonicSeed),
      _walletMetadataRepository.storeWalletMetadata(walletMetadata),
      _walletRepositoryManager.registerWallet(walletMetadata),
    ]);
  }
}
