import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import 'package:preferences/preferences.dart' show ActiveEnvironmentReader;

import 'provisioning_failure.dart';
import 'src/wallet_provisioning.dart';

/// Creates or resumes the default pair and returns its committed identities.
class DefaultWalletProvisioning {
  final Secrets _secrets;
  final WalletInventory _inventory;
  final ActiveEnvironmentReader _environment;
  final WalletProvisioning _accounts;

  const DefaultWalletProvisioning({
    required this._secrets,
    required this._inventory,
    required this._environment,
    required this._accounts,
  });

  @useResult
  Future<Result<List<WalletRegistration>, DefaultWalletFailure>> execute({
    List<String>? mnemonicWords,
    Language? language,
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
    if ((mnemonicWords == null) != (language == null)) {
      throw ArgumentError('Mnemonic words require their language');
    }
    if (secret != null && !secret.info.isMnemonic) {
      return const Err(DefaultWalletMnemonicRequiredFailure());
    }
    try {
      final NetworkEnv environment;
      switch (await _environment.readActiveEnvironment()) {
        case Ok(:final value):
          environment = value.networkEnv;
        case Err():
          log.warning('Default wallet setup failed: preferences');
          return const Err(DefaultWalletUnexpectedFailure());
      }
      if (expectedNetwork != null && environment != expectedNetwork) {
        return const Err(DefaultWalletNetworkChangedFailure());
      }
      if (environment == NetworkEnv.signet) {
        return const Err(DefaultWalletNetworkChangedFailure());
      }
      if (await _accounts.resume() case Err()) {
        log.warning('Default wallet setup failed: provisioning resume');
        return const Err(DefaultWalletUnexpectedFailure());
      }
      final bitcoin = BitcoinNetwork.values.byName(environment.name);
      final liquid = LiquidNetwork.values.byName(environment.name);
      final existing = <WalletRegistration>[];
      for (final network in <Network>[bitcoin, liquid]) {
        switch (await _inventory.walletsForNetwork(network)) {
          case Ok(value: final selection) when selection.isComplete:
            if (selection.defaults.length > 1) {
              return const Err(DefaultWalletStorageFailure());
            }
            existing.addAll(selection.defaults);
          case Ok() || Err():
            return const Err(DefaultWalletStorageFailure());
        }
      }
      final hasBitcoin = existing.any((wallet) => wallet.network == bitcoin);
      final hasLiquid = existing.any((wallet) => wallet.network == liquid);
      Secret? resumedSecret;
      if (existing.isNotEmpty) {
        final fingerprint = existing.first.secretFingerprint;
        if (fingerprint == null ||
            existing.any(
              (wallet) =>
                  wallet.signer != WalletSigner.local ||
                  wallet.secretFingerprint != fingerprint,
            )) {
          return const Err(DefaultWalletAlreadyExistsFailure());
        }
        if (secret != null && secret.id != fingerprint) {
          return const Err(DefaultWalletAlreadyExistsFailure());
        }
        if (hasBitcoin && hasLiquid) {
          if (secret != null || mnemonicWords != null) {
            return const Err(DefaultWalletAlreadyExistsFailure());
          }
          return Ok(existing);
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
        if (!resumedSecret.info.isMnemonic) {
          return const Err(DefaultWalletMnemonicRequiredFailure());
        }
        if (mnemonicWords != null) {
          final words = await resumedSecret.verify.mnemonic(mnemonicWords);
          final phrase = await resumedSecret.verify.passphrase(passphrase);
          if (words is! Ok<bool, SecretFailure> ||
              !words.value ||
              phrase is! Ok<bool, SecretFailure> ||
              !phrase.value) {
            return const Err(DefaultWalletAlreadyExistsFailure());
          }
        }
      }
      final generated =
          resumedSecret == null && secret == null && mnemonicWords == null;
      final birthday = generated ? DateTime.now().toUtc() : null;
      final current =
          resumedSecret ??
          secret ??
          switch (await _resolveSecret(mnemonicWords, language, passphrase)) {
            Ok(:final value) => value,
            Err() => null,
          };
      if (current == null) return const Err(DefaultWalletSecretFailure());
      if (!current.info.isMnemonic) {
        return const Err(DefaultWalletMnemonicRequiredFailure());
      }
      try {
        for (final network in <Network>[
          if (!hasBitcoin) bitcoin,
          if (!hasLiquid) liquid,
        ]) {
          final String id;
          switch (await _accounts.createDefault(
            current,
            network,
            birthday: birthday,
          )) {
            case Ok(:final value):
              id = value;
            case Err(:final failure):
              log.warning(
                'Default wallet creation failed: ${failure.runtimeType}',
              );
              return const Err(DefaultWalletCreationFailure());
          }
          final committed = await _inventory.readWallet(id);
          if (committed is! Ok<WalletRegistration, SecretFailure>) {
            return const Err(DefaultWalletStorageFailure());
          }
          final wallet = committed.value;
          if (wallet.network != network ||
              !wallet.isDefault ||
              wallet.signer != WalletSigner.local ||
              wallet.secretFingerprint != current.id) {
            return const Err(DefaultWalletStorageFailure());
          }
          existing.add(wallet);
        }
        return Ok(existing);
      } on Exception catch (error) {
        log.warning('Default wallet creation failed: ${error.runtimeType}');
        return const Err(DefaultWalletCreationFailure());
      }
    } on Exception catch (error) {
      log.warning('Default wallet setup failed: ${error.runtimeType}');
      return const Err(DefaultWalletUnexpectedFailure());
    }
  }

  Future<Result<Secret, SecretFailure>> _resolveSecret(
    List<String>? words,
    Language? language,
    String passphrase,
  ) async {
    if (words == null || language == null) return _secrets.generate();
    final imported = await _secrets.import(
      words: words,
      language: language,
      passphrase: passphrase,
    );
    return switch (imported) {
      Err(failure: SecretAlreadyExistsFailure(:final id)) => _secrets.fetch(id),
      _ => imported,
    };
  }
}
