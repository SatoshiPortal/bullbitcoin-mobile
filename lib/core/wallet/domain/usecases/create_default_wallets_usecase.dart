import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/data/services/mnemonic_generator.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

import 'package:bb_mobile/core/wallet/domain/wallet_failure_bridge.dart';
import 'package:bb_mobile/core/utils/result.dart';

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

      final existing = switch (await _wallet.getWallets(
        onlyDefaults: true,
        environment: environment,
      )) {
        Ok(:final value) => value,
        // Intentional, not pending work: onboarding is the only consumer and
        // it deliberately catches this throw in its own use-cases, mapping it
        // to OnboardingFailure — see the doc on OnboardingFailure itself. That
        // is rule 11's "feature use-case wrapping a shared core" boundary, so
        // this signature is not waiting on anything.
        Err(:final failure) => throw WalletFailureException(failure),
      };
      final hasBitcoin = existing.any((w) => w.network.isBitcoin);
      final hasLiquid = existing.any((w) => w.network.isLiquid);
      if (hasBitcoin && hasLiquid) return existing;

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
            // Rollback must not mask the original creation failure, but it
            // still has to report: the repository returns a Result now, so
            // discarding it would silence this log for every repository-level
            // failure and leave a half-created wallet set unexplained.
            if (await _wallet.deleteWallet(walletId: wallet.id) case Err(
              :final failure,
            )) {
              log.severe(
                message: 'CreateDefaultWalletsUsecase: rollback failed',
                error: failure.runtimeType,
                trace: StackTrace.current,
              );
            }
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
    } catch (e) {
      throw CreateDefaultWalletsException(e.toString());
    }
  }
}

class CreateDefaultWalletsException extends BullException {
  CreateDefaultWalletsException(super.message);
}
