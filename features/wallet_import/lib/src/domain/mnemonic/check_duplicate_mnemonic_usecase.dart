import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart' hide Language;
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

class CheckDuplicateMnemonicUsecase {
  final Secrets _secrets;
  final WalletInventory _inventory;
  final Preferences _settings;

  CheckDuplicateMnemonicUsecase({
    required this._secrets,
    required this._inventory,
    required this._settings,
  });

  @useResult
  Future<Result<bool, ImportMnemonicFailure>> isReferenced(
    Fingerprint id,
    BitcoinNetwork network,
  ) async {
    return switch (await _inventory.walletsForNetwork(network)) {
      Ok(:final value)
          when value.wallets.any((wallet) => wallet.secretFingerprint == id) =>
        const Ok(true),
      Ok(value: WalletSelection(isComplete: true)) => const Ok(false),
      Ok() || Err() => const Err(
        ImportMnemonicUnexpectedFailure('Wallet inventory unavailable'),
      ),
    };
  }

  @useResult
  Future<Result<void, ImportMnemonicFailure>> execute({
    required List<String> mnemonicWords,
    required Language language,
    String passphrase = '',
  }) async {
    final existing = await _secrets.find(
      words: mnemonicWords,
      language: language,
      passphrase: passphrase,
    );
    switch (existing) {
      case Err(:final failure):
        return Err(
          ImportMnemonicUnexpectedFailure(failure.runtimeType.toString()),
        );
      case Ok(value: null):
        return const Ok(null);
      case Ok(value: final secret?):
        final settings = await _settings.fetch();
        if (settings is! Ok<SettingsEntity, PreferencesFailure>) {
          return const Err(
            ImportMnemonicUnexpectedFailure('Preferences unavailable'),
          );
        }
        final environment = settings.value.environment.networkEnv;
        if (environment == NetworkEnv.signet) {
          return const Err(
            ImportMnemonicUnexpectedFailure('Unsupported network'),
          );
        }
        final network = BitcoinNetwork.values.byName(environment.name);
        return switch (await isReferenced(secret.id, network)) {
          Ok(value: true) => const Err(ImportMnemonicDuplicateFailure()),
          Ok(value: false) => const Ok(null),
          Err(:final failure) => Err(failure),
        };
    }
  }
}
