import 'package:bb_mobile/features/wallet/domain/default_wallet_secret_policy.dart';
import 'package:bb_mobile/features/wallet/domain/default_wallet_failure.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:secrets/secrets.dart';
import 'package:meta/meta.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:primitives/primitives.dart'
    show Err, Fingerprint, NetworkEnv, Ok, Result;

/// Creates the default Bitcoin and Liquid wallets from one secret: generated, imported from words, or restored by the secrets package.
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

  @useResult
  Future<Result<List<Wallet>, DefaultWalletFailure>> execute({
    List<String>? mnemonicWords,
    Secret? secret,
    String passphrase = '',
    NetworkEnv? expectedNetwork,
  }) async {
    if (secret != null && mnemonicWords != null) {
      throw ArgumentError('Provide either a secret or mnemonic words');
    }
    if (passphrase.isNotEmpty && mnemonicWords == null) {
      throw ArgumentError('A passphrase requires mnemonic words');
    }
    if (secret != null && defaultWalletSecretRefusal(secret.info) != null) {
      return const Err(DefaultWalletMnemonicRequiredFailure());
    }
    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;

      if (expectedNetwork != null &&
          environment.networkEnv != expectedNetwork) {
        return const Err(DefaultWalletNetworkChangedFailure());
      }
      await _resumeProvisioning?.call();

      const scriptType = ScriptType.bip84;
      final bitcoinNetwork = Network.fromEnvironment(
        environment: environment.networkEnv,
        isLiquid: false,
      );
      final liquidNetwork = Network.fromEnvironment(
        environment: environment.networkEnv,
        isLiquid: true,
      );

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
      Secret? resumedSecret;
      if (hasBitcoin && hasLiquid) {
        // A restore must never reuse or certify a complete existing pair.
        if (secret != null || mnemonicWords != null) {
          return const Err(DefaultWalletAlreadyExistsFailure());
        }
        return Ok(existing);
      }
      if (existing.isNotEmpty) {
        final fingerprint = Fingerprint(existing.first.masterFingerprint);
        if (existing.any(
              (wallet) => Fingerprint(wallet.masterFingerprint) != fingerprint,
            ) ||
            (secret != null && secret.id != fingerprint)) {
          return const Err(DefaultWalletAlreadyExistsFailure());
        }
        resumedSecret =
            secret ??
            switch (await _secrets.fetch(fingerprint)) {
              Ok(:final value) => value,
              Err() => null,
            };
        if (resumedSecret == null) {
          return const Err(DefaultWalletSecretFailure());
        }
        if (defaultWalletSecretRefusal(resumedSecret.info) != null) {
          return const Err(DefaultWalletMnemonicRequiredFailure());
        }
        if (mnemonicWords != null) {
          final matchesWords = await resumedSecret.verify.mnemonic(
            mnemonicWords,
          );
          final matchesPassphrase = await resumedSecret.verify.passphrase(
            passphrase,
          );
          if (matchesWords is! Ok<bool, SecretFailure> ||
              !matchesWords.value ||
              matchesPassphrase is! Ok<bool, SecretFailure> ||
              !matchesPassphrase.value) {
            return const Err(DefaultWalletAlreadyExistsFailure());
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
          switch (await _resolveSecret(mnemonicWords, passphrase)) {
            Ok(:final value) => value,
            Err() => null,
          };
      // An import of words can resolve to an equivalent entry stored earlier
      // in another wordlist: check what was resolved, before any wallet write.
      if (defaultSecret == null) return const Err(DefaultWalletSecretFailure());
      if (defaultWalletSecretRefusal(defaultSecret.info) != null) {
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
      } on Object catch (e) {
        log.warning('Default wallet creation failed: ${e.runtimeType}');
        // The native writer retains catalog rows and custody for an explicit
        // provisioning retry. Never delete a successfully created member.
        return const Err(DefaultWalletCreationFailure());
      }

      return Ok([...existing, ...created]);
    } on Object catch (e) {
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
