import 'package:bb_mobile/core/seed/domain/entity/bip85_bip39_language.dart';
import 'package:bb_mobile/core/seed/domain/entity/bip85_bip39_word_count.dart';
import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

class CreateBip85DerivedWalletUseCase {
  final SeedRepository _seedRepository;
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;

  CreateBip85DerivedWalletUseCase({
    required SeedRepository seedRepository,
    required WalletRepository walletRepository,
    required SettingsRepository settingsRepository,
  }) : _seedRepository = seedRepository,
       _walletRepository = walletRepository,
       _settingsRepository = settingsRepository;

  Future<Wallet> execute({
    required String masterSeedFingerprint,
    required int accountIndex,
    required ScriptType scriptType,
    bool isLiquid = false,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final network = Network.fromEnvironment(
        isTestnet: settings.environment.isTestnet,
        isLiquid: isLiquid,
      );
      final mnemonicSeed = await _seedRepository
          .createBip85DerivedFromMasterSeed(
            masterSeedFingerprint: masterSeedFingerprint,
            accountIndex: accountIndex,
            language: Bip85Bip39Language.english,
            wordCount: Bip85Bip39WordCount.twelve,
          );

      final wallet = await _walletRepository.createWallet(
        seed: mnemonicSeed,
        network: network,
        scriptType: scriptType,
        isDefault: false,
      );

      return wallet;
    } catch (e) {
      throw CreateBip85DerivedWalletException(
        'Failed to create BIP85 derived wallet: $e',
      );
    }
  }
}

class CreateBip85DerivedWalletException implements Exception {
  final String message;

  CreateBip85DerivedWalletException(this.message);

  @override
  String toString() => '[CreateBip85DerivedWalletUsecase]: $message';
}
