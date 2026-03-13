import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/errors.dart';

class ImportWalletUsecase {
  final CheckDuplicateMnemonicUsecase _checkDuplicateMnemonicUsecase;
  final SeedRepository _seedRepository;
  final SettingsRepository _settingsRepository;
  final WalletRepository _wallet;

  ImportWalletUsecase({
    required CheckDuplicateMnemonicUsecase checkDuplicateMnemonicUsecase,
    required SeedRepository seedRepository,
    required SettingsRepository settingsRepository,
    required WalletRepository walletRepository,
  }) : _checkDuplicateMnemonicUsecase = checkDuplicateMnemonicUsecase,
       _seedRepository = seedRepository,
       _settingsRepository = settingsRepository,
       _wallet = walletRepository;

  Future<Wallet> execute({
    required List<String> mnemonicWords,
    ScriptType scriptType = ScriptType.bip84,
    String passphrase = '',
    String? label,
  }) async {
    try {
      await _checkDuplicateMnemonicUsecase.execute(
        mnemonicWords: mnemonicWords,
        passphrase: passphrase,
      );

      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final bitcoinNetwork = environment.isMainnet
          ? Network.bitcoinMainnet
          : Network.bitcoinTestnet;

      final seed = await _seedRepository.createFromMnemonic(
        mnemonicWords: mnemonicWords,
        passphrase: passphrase,
      );

      final wallet = _wallet.createWallet(
        seed: seed,
        network: bitcoinNetwork,
        scriptType: scriptType,
        isDefault: false,
        sync: false,
        label: label,
      );

      log.fine('Wallet imported');

      return wallet;
    } catch (e) {
      if (e is DuplicateMnemonicException) rethrow;
      throw ImportWalletException(e.toString());
    }
  }
}
