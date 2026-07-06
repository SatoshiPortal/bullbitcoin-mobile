import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:meta/meta.dart';

class ImportWalletUsecase {
  final CheckDuplicateMnemonicUsecase _checkDuplicateMnemonicUsecase;
  final SeedRepository _seedRepository;
  final SettingsRepository _settingsRepository;
  final WalletRepository _wallet;

  ImportWalletUsecase({
    required this._checkDuplicateMnemonicUsecase,
    required this._seedRepository,
    required this._settingsRepository,
    required WalletRepository walletRepository,
  }) : _wallet = walletRepository;

  @useResult
  Future<Result<Wallet, ImportMnemonicFailure>> execute({
    required List<String> mnemonicWords,
    ScriptType scriptType = ScriptType.bip84,
    String passphrase = '',
    String? label,
  }) async {
    switch (await _checkDuplicateMnemonicUsecase.execute(
      mnemonicWords: mnemonicWords,
      passphrase: passphrase,
    )) {
      case Err(:final failure):
        return Err(failure);
      case Ok():
        break;
    }

    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final bitcoinNetwork = environment.isMainnet
          ? Network.bitcoinMainnet
          : Network.bitcoinTestnet;

      final seed = await _seedRepository.createFromMnemonic(
        mnemonicWords: mnemonicWords,
        passphrase: passphrase,
      );

      final wallet = await _wallet.createWallet(
        seed: seed,
        network: bitcoinNetwork,
        scriptType: scriptType,
        isDefault: false,
        sync: false,
        label: label,
      );

      log.fine('Wallet imported');

      return Ok(wallet);
    } catch (e, st) {
      log.severe(message: 'Import wallet failed', error: e, trace: st);
      return Err(ImportMnemonicUnexpectedFailure(e.toString()));
    }
  }
}
