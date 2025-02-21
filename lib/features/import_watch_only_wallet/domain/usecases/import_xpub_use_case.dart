import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/core/domain/services/wallet_metadata_derivation_service.dart';
import 'package:bb_mobile/core/domain/services/wallet_repository_manager.dart';

class ImportXpubUseCase {
  final SettingsRepository _settingsRepository;
  final WalletMetadataDerivationService _walletMetadataDerivationService;
  final WalletMetadataRepository _walletMetadataRepository;
  final WalletRepositoryManager _walletRepositoryManager;

  ImportXpubUseCase({
    required SettingsRepository settingsRepository,
    required WalletMetadataDerivationService walletMetadataDerivationService,
    required WalletMetadataRepository walletMetadataRepository,
    required WalletRepositoryManager walletRepositoryManager,
  })  : _settingsRepository = settingsRepository,
        _walletMetadataDerivationService = walletMetadataDerivationService,
        _walletMetadataRepository = walletMetadataRepository,
        _walletRepositoryManager = walletRepositoryManager;

  Future<void> execute({
    required String xpub,
    required ScriptType scriptType,
    String label = '',
  }) async {
    final environment = await _settingsRepository.getEnvironment();

    final walletMetadata = await _walletMetadataDerivationService.fromXpub(
      xpub: xpub,
      network: environment == Environment.mainnet
          ? Network.bitcoinMainnet
          : Network.bitcoinTestnet,
      scriptType: scriptType,
      label: label,
    );

    // Store the wallet metadata and register the wallet in the
    //  wallet repository manager so it can be used in the app.
    await Future.wait([
      _walletMetadataRepository.storeWalletMetadata(walletMetadata),
      _walletRepositoryManager.registerWallet(walletMetadata),
    ]);
  }
}
