import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:secrets/secrets.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/utils/result.dart';

/// Creates the default Bitcoin and Liquid wallets from one secret: generated, imported from words, or restored by the secrets package.
///
/// Default wallets never carry a BIP39 passphrase. Supplied handles are checked before any wallet or storage operation. Several paths are only correct because the default secret is passphrase-less, and each would regress if one were allowed here:
///
/// - **Liquid.** lwk derives from the words alone (lwk_signer 0.18.0 hard-codes `to_seed("")`), so the Liquid default would belong to the passphrase-less sibling while the Bitcoin default belonged to the passphrase secret: two defaults on two different seeds, and a passphrase that protects no Liquid funds.
/// - **RecoverBull.** The vault carries the words only, so restoring it gives the passphrase-less wallet — a different Bitcoin wallet — while the vault key is derived from the seed *with* the passphrase.
/// - **Swap key.** Derived from the default Bitcoin wallet; the package sends the passphrase to boltz, released builds up to v6.13.4 did not, so a passphrase default would re-derive a different swap key after a restore and lose sight of earlier swaps.
/// - **BIP85 children.** Derived from the default wallet's seed, passphrase included, so every child would change with it.
/// - **Physical backup check.** `verify.mnemonic` compares the words only; the passphrase would go unverified.
///
/// Supporting a passphrase on the default wallets therefore starts with lwk supporting one, then a decision for each path above. Until then a passphrase secret is an imported, non-default wallet (`ImportWalletUsecase`, `isDefault: false`).
class CreateDefaultWalletsUsecase {
  final Secrets _secrets;
  final SettingsRepository _settingsRepository;
  final WalletRepository _wallet;

  CreateDefaultWalletsUsecase({
    required this._secrets,
    required this._settingsRepository,
    required WalletRepository walletRepository,
  }) : _wallet = walletRepository;

  Future<List<Wallet>> execute({
    List<String>? mnemonicWords,
    Secret? secret,
  }) async {
    if (secret != null && mnemonicWords != null) {
      throw ArgumentError('Provide either a secret or mnemonic words');
    }
    if (secret?.info.hasPassphrase ?? false) {
      throw ArgumentError('Default wallets cannot use a passphrase');
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
        // Wrapped into this use-case's own exception by the catch below.
        Err(:final failure) => throw CreateDefaultWalletsException(
          'existing defaults read failed: ${failure.runtimeType}',
        ),
      };
      final hasBitcoin = existing.any((w) => w.network.isBitcoin);
      final hasLiquid = existing.any((w) => w.network.isLiquid);
      if (existing.isNotEmpty) {
        // A restore must never reuse or certify existing defaults. A partial
        // setup is also refused rather than mixing secrets across networks.
        if (secret != null ||
            mnemonicWords != null ||
            !hasBitcoin ||
            !hasLiquid) {
          throw StateError('Default wallets already exist');
        }
        return existing;
      }

      final isGenerated = secret == null && mnemonicWords == null;
      final DateTime? birthday = isGenerated ? DateTime.now().toUtc() : null;
      // Generation and import both happen inside the package; the words never come back here.
      final defaultSecret =
          secret ??
          switch (await _resolveSecret(mnemonicWords)) {
            Ok(:final value) => value,
            Err(:final failure) => throw StateError(
              'could not create the default secret: ${failure.runtimeType}',
            ),
          };

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
      } catch (_) {
        var rollbackComplete = true;
        for (final wallet in created) {
          try {
            // Rollback must not mask the original creation failure, but it
            // still has to report: the repository returns a Result now, so
            // discarding it would silence this log for every repository-level
            // failure and leave a half-created wallet set unexplained.
            if (await _wallet.deleteWallet(walletId: wallet.id) case Err(
              :final failure,
            )) {
              rollbackComplete = false;
              log.severe(
                message: 'CreateDefaultWalletsUsecase: rollback failed',
                error: failure.runtimeType,
                trace: StackTrace.current,
              );
            }
          } catch (e, stackTrace) {
            rollbackComplete = false;
            log.severe(
              message: 'CreateDefaultWalletsUsecase: rollback failed',
              error: e,
              trace: stackTrace,
            );
          }
        }
        // Imported and supplied custody belongs to the caller. A generated
        // secret belongs to this setup, but must survive if a wallet remains.
        if (isGenerated && rollbackComplete) {
          try {
            if (await _secrets.trash(defaultSecret.id) case Err(
              :final failure,
            )) {
              log.severe(
                message: 'CreateDefaultWalletsUsecase: secret rollback failed',
                error: failure.runtimeType,
                trace: StackTrace.current,
              );
            }
          } catch (e, stackTrace) {
            log.severe(
              message: 'CreateDefaultWalletsUsecase: secret rollback failed',
              error: e.runtimeType,
              trace: stackTrace,
            );
          }
        }
        rethrow;
      }

      return [...existing, ...created];
    } on CreateDefaultWalletsException {
      rethrow;
    } catch (e) {
      throw CreateDefaultWalletsException(e.toString());
    }
  }

  Future<Result<Secret, SecretFailure>> _resolveSecret(
    List<String>? words,
  ) async {
    if (words == null) return _secrets.generate();
    final imported = await _secrets.import(words: words);
    // Import reports a duplicate only after comparing the full seed. Reuse it
    // when retrying wallet creation, without rewriting or deleting its storage.
    return switch (imported) {
      Err(failure: SecretAlreadyExistsFailure(:final id)) => _secrets.fetch(id),
      _ => imported,
    };
  }
}

class CreateDefaultWalletsException extends BullException {
  CreateDefaultWalletsException(super.message);
}
