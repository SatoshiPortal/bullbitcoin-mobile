import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/data/services/mnemonic_generator.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/inconsistent_wallet_state_exception.dart';

class CreateDefaultWalletsUsecase {
  final SeedRepository _seedRepository;
  final SettingsRepository _settingsRepository;
  final MnemonicGenerator _mnemonicGenerator;
  final WalletRepository _wallet;

  CreateDefaultWalletsUsecase({
    required this._seedRepository,
    required this._settingsRepository,
    required this._mnemonicGenerator,
    required WalletRepository walletRepository,
  }) : _wallet = walletRepository;

  Future<List<Wallet>> execute({
    List<String>? mnemonicWords,
    String? passphrase,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;

      const scriptType = ScriptType.bip84;
      final bitcoinNetwork = environment.isMainnet
          ? Network.bitcoinMainnet
          : Network.bitcoinTestnet;
      final liquidNetwork = environment.isMainnet
          ? Network.liquidMainnet
          : Network.liquidTestnet;

      final existing = await _wallet.getWallets(
        onlyDefaults: true,
        environment: environment,
      );
      final hasBitcoin = existing.any((w) => w.network.isBitcoin);
      final hasLiquid = existing.any((w) => w.network.isLiquid);
      if (hasBitcoin && hasLiquid) {
        await _restoreOrRequireSeeds(
          existing,
          mnemonicWords: mnemonicWords,
          passphrase: passphrase,
        );
        return existing;
      }

      final isGenerated = mnemonicWords == null;
      final mnemonic = mnemonicWords ?? _mnemonicGenerator.generate();
      final DateTime? birthday = isGenerated ? DateTime.now().toUtc() : null;
      final seed = await _seedRepository.createFromMnemonic(
        mnemonicWords: mnemonic,
        passphrase: passphrase,
      );

      final created = <Wallet>[];
      try {
        if (!hasBitcoin) {
          created.add(
            await _wallet.createWallet(
              seed: seed,
              network: bitcoinNetwork,
              scriptType: scriptType,
              isDefault: true,
              birthday: birthday,
            ),
          );
        }
        if (!hasLiquid) {
          created.add(
            await _wallet.createWallet(
              seed: seed,
              network: liquidNetwork,
              scriptType: scriptType,
              isDefault: true,
              birthday: birthday,
            ),
          );
        }
      } catch (_) {
        for (final wallet in created) {
          try {
            await _wallet.deleteWallet(walletId: wallet.id);
          } catch (e, stackTrace) {
            log.severe(
              message: 'CreateDefaultWalletsUsecase: rollback failed',
              error: e,
              trace: stackTrace,
            );
          }
        }
        rethrow;
      }

      return [...existing, ...created];
    } on InconsistentWalletStateException {
      rethrow;
    } catch (e) {
      throw CreateDefaultWalletsException(e.toString());
    }
  }

  Future<void> _restoreOrRequireSeeds(
    List<Wallet> wallets, {
    List<String>? mnemonicWords,
    String? passphrase,
  }) async {
    for (final fingerprint
        in wallets.map((wallet) => wallet.masterFingerprint).toSet()) {
      if (await _seedRepository.exists(fingerprint)) continue;
      if (mnemonicWords != null &&
          _seedRepository.fingerprintFor(
                mnemonicWords: mnemonicWords,
                passphrase: passphrase,
              ) ==
              fingerprint) {
        await _seedRepository.createFromMnemonic(
          mnemonicWords: mnemonicWords,
          passphrase: passphrase,
        );
        continue;
      }
      final error = InconsistentWalletStateException(fingerprint: fingerprint);
      log.severe(
        message: 'Default wallet records exist without their seed',
        error: error.runtimeType,
        trace: StackTrace.current,
      );
      throw error;
    }
  }
}

class CreateDefaultWalletsException extends BullException {
  CreateDefaultWalletsException(super.message);
}
