import 'package:bb_mobile/features/wallet/domain/default_wallet_failure.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:secrets/secrets.dart';
import 'package:meta/meta.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;

/// Creates the default Bitcoin and Liquid wallets from one secret: generated, imported from words, or restored by the secrets package.
class CreateDefaultWalletsUsecase {
  final Secrets _secrets;
  final SettingsRepository _settingsRepository;
  final WalletRepository _wallet;

  CreateDefaultWalletsUsecase({
    required this._secrets,
    required this._settingsRepository,
    required WalletRepository walletRepository,
  }) : _wallet = walletRepository;

  @useResult
  Future<Result<List<Wallet>, DefaultWalletFailure>> execute({
    List<String>? mnemonicWords,
    Secret? secret,
    String passphrase = '',
  }) async {
    if (secret != null && mnemonicWords != null) {
      throw ArgumentError('Provide either a secret or mnemonic words');
    }
    if (passphrase.isNotEmpty && mnemonicWords == null) {
      throw ArgumentError('A passphrase requires mnemonic words');
    }
    if (secret != null && !secret.info.isMnemonic) {
      return const Err(DefaultWalletMnemonicRequiredFailure());
    }
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
        Err() => null,
      };
      if (existing == null) return const Err(DefaultWalletStorageFailure());
      final hasBitcoin = existing.any((w) => w.network.isBitcoin);
      final hasLiquid = existing.any((w) => w.network.isLiquid);
      if (existing.isNotEmpty) {
        // A restore must never reuse or certify existing defaults. A partial
        // setup is also refused rather than mixing secrets across networks.
        if (secret != null ||
            mnemonicWords != null ||
            !hasBitcoin ||
            !hasLiquid) {
          return const Err(DefaultWalletAlreadyExistsFailure());
        }
        return Ok(existing);
      }

      final isGenerated = secret == null && mnemonicWords == null;
      final DateTime? birthday = isGenerated ? DateTime.now().toUtc() : null;
      // Generation and import both happen inside the package; the words never come back here.
      final defaultSecret =
          secret ??
          switch (await _resolveSecret(mnemonicWords, passphrase)) {
            Ok(:final value) => value,
            Err() => null,
          };
      // An import of words can resolve to an equivalent entry stored earlier
      // in another wordlist: check what was resolved, before any wallet write.
      if (defaultSecret == null) return const Err(DefaultWalletSecretFailure());
      if (!defaultSecret.info.isMnemonic) {
        return const Err(DefaultWalletMnemonicRequiredFailure());
      }

      final created = <Wallet>[];
      try {
        if (!hasBitcoin) {
          created.add(
            await _wallet.createWallet(
              secret: defaultSecret,
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
              secret: defaultSecret,
              network: liquidNetwork,
              scriptType: scriptType,
              isDefault: true,
              birthday: birthday,
            ),
          );
        }
      } on Exception catch (e) {
        log.warning('Default wallet creation failed: ${e.runtimeType}');
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
              error: e.runtimeType,
              trace: stackTrace,
            );
          }
        }
        return const Err(DefaultWalletCreationFailure());
      }

      return Ok([...existing, ...created]);
    } on Exception catch (e) {
      log.warning('Default wallet setup failed: ${e.runtimeType}');
      return const Err(DefaultWalletUnexpectedFailure());
    }
  }

  Future<Result<Secret, SecretFailure>> _resolveSecret(
    List<String>? words,
    String passphrase,
  ) async {
    if (words == null) return _secrets.generate();
    final imported = await _secrets.import(
      words: words,
      passphrase: passphrase,
    );
    // Import reports a duplicate only after comparing the full seed. Reuse it
    // when retrying wallet creation, without rewriting or deleting its storage.
    return switch (imported) {
      Err(failure: SecretAlreadyExistsFailure(:final id)) => _secrets.fetch(id),
      _ => imported,
    };
  }
}
