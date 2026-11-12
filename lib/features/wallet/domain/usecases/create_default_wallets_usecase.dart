import 'package:bb_mobile/features/wallet/domain/default_wallet_secret_policy.dart';
import 'package:primitives/primitives.dart' show Fingerprint, NetworkEnv;
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:secrets/secrets.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/core/utils/result.dart';

/// Creates the default Bitcoin and Liquid wallets from one secret: generated, imported from words, or restored by the secrets package.
///
/// Default wallets never carry a BIP39 passphrase. Supplied handles are checked before any wallet or storage operation. Several paths are only correct because the default secret is passphrase-less, and each would regress if one were allowed here:
///
/// - **Liquid.** Liquid now derives from the full seed, passphrase included, but every existing Liquid wallet was created from a passphrase-less default secret, and released builds derived Liquid from the words alone: a passphrase default restored on an older build would find another Liquid wallet.
/// - **RecoverBull.** The vault carries the words only, so restoring it gives the passphrase-less wallet — a different Bitcoin wallet — while the vault key is derived from the seed *with* the passphrase.
/// - **Swap key.** Derived from the default Bitcoin wallet; the package sends the passphrase to boltz, released builds up to v6.13.4 did not, so a passphrase default would re-derive a different swap key after a restore and lose sight of earlier swaps.
/// - **BIP85 children.** Derived from the default wallet's seed, passphrase included, so every child would change with it.
/// - **Physical backup check.** `verify.mnemonic` compares the words only; the passphrase would go unverified.
///
/// Supporting a passphrase on the default wallets therefore starts with a decision for each path above. Until then a passphrase secret is an imported, non-default wallet (`ImportWalletUsecase`, `isDefault: false`).
class CreateDefaultWalletsUsecase {
  final Future<void> Function()? _resumeProvisioning;
  final Secrets _secrets;
  final SettingsRepository _settingsRepository;
  final WalletRepository _wallet;

  CreateDefaultWalletsUsecase({
    this._resumeProvisioning,
    required this._secrets,
    required this._settingsRepository,
    required WalletRepository walletRepository,
  }) : _wallet = walletRepository;

  Future<List<Wallet>> execute({
    List<String>? mnemonicWords,
    Secret? secret,
    NetworkEnv? expectedNetwork,
  }) async {
    if (secret != null && mnemonicWords != null) {
      throw ArgumentError('Provide either a secret or mnemonic words');
    }
    if (secret != null) _requireDefaultCapable(secret.info);
    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      if (expectedNetwork != null &&
          environment.networkEnv != expectedNetwork) {
        throw CreateDefaultWalletsException('Selected network changed');
      }
      await _resumeProvisioning?.call();

      const scriptType = ScriptType.bip84;
      final bitcoinNetwork = Network.fromEnvironment(
        environment: settings.environment.networkEnv,
        isLiquid: false,
      );
      final liquidNetwork = Network.fromEnvironment(
        environment: settings.environment.networkEnv,
        isLiquid: true,
      );
      final supportsLiquid = liquidNetwork != Network.liquidRegtest;

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
      Secret? resumedSecret;
      if (hasBitcoin && (!supportsLiquid || hasLiquid)) {
        if (secret != null || mnemonicWords != null) {
          throw CreateDefaultWalletsException('Default wallets already exist');
        }
        return existing;
      }
      if (existing.isNotEmpty) {
        final fingerprint = Fingerprint(existing.first.masterFingerprint);
        if (existing.any(
              (wallet) => Fingerprint(wallet.masterFingerprint) != fingerprint,
            ) ||
            (secret != null && secret.id != fingerprint)) {
          throw CreateDefaultWalletsException(
            'Default wallet custody does not match',
          );
        }
        resumedSecret =
            secret ??
            switch (await _secrets.fetch(fingerprint)) {
              Ok(:final value) => value,
              Err(:final failure) => throw CreateDefaultWalletsException(
                'Default secret unavailable: ${failure.runtimeType}',
              ),
            };
        _requireDefaultCapable(resumedSecret.info);
        if (mnemonicWords != null) {
          switch (await resumedSecret.verify.mnemonic(mnemonicWords)) {
            case Ok(value: true):
              break;
            case _:
              throw CreateDefaultWalletsException(
                'Default wallet custody does not match',
              );
          }
        }
        log.warning('Resuming partial default wallet provisioning');
      }

      final isGenerated =
          resumedSecret == null && secret == null && mnemonicWords == null;
      final DateTime? birthday = isGenerated ? DateTime.now().toUtc() : null;
      // Generation and import both happen inside the package; the words never come back here.
      final defaultSecret =
          resumedSecret ??
          secret ??
          switch (await _resolveSecret(mnemonicWords)) {
            Ok(:final value) => value,
            Err(:final failure) => throw CreateDefaultWalletsException(
              'could not create the default secret: ${failure.runtimeType}',
            ),
          };

      _requireDefaultCapable(defaultSecret.info);
      final created = <Wallet>[];
      // Keep successful members and their custody if a later member fails.
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
      if (supportsLiquid && !hasLiquid) {
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

      return [...existing, ...created];
    } on CreateDefaultWalletsException {
      rethrow;
    } on Exception catch (e) {
      throw CreateDefaultWalletsException(e.toString());
    }
  }

  /// Refuses a secret both default wallets cannot be built from, before any wallet write.
  static void _requireDefaultCapable(SecretInfo info) {
    final refusal = defaultWalletSecretRefusal(info);
    if (refusal == null) return;
    final message = switch (refusal) {
      DefaultWalletSecretRefusal.passphrase =>
        'Default wallets cannot use a passphrase',
      DefaultWalletSecretRefusal.nonMnemonic =>
        'Default wallets require a mnemonic, not a raw seed',
    };
    throw CreateDefaultWalletsException(message, secretRefusal: refusal);
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
  final DefaultWalletSecretRefusal? secretRefusal;

  CreateDefaultWalletsException(super.message, {this.secretRefusal});
}
