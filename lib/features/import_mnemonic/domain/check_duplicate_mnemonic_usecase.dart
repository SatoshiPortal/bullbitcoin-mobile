import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' show Network;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Language;
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' hide Network;
import 'package:secrets/secrets.dart';

class CheckDuplicateMnemonicUsecase {
  final Secrets _secrets;

  final WalletMetadataDatasource _metadata;
  final SettingsRepository _settings;
  int _invalidCount = 0;

  CheckDuplicateMnemonicUsecase({
    required this._secrets,
    required this._metadata,
    required this._settings,
  });

  Future<bool> isReferenced(Fingerprint id, Network network) async {
    var referenced = false;
    var invalid = 0;
    for (final row in await _metadata.fetchAll()) {
      // Only the legacy origin decoder throws strings; other failures surface.
      try {
        if (row.seedFingerprint == id && row.network == network) {
          referenced = true;
        }
      } on String {
        invalid++;
      }
    }
    if (invalid != _invalidCount) {
      _invalidCount = invalid;
      log.warning('Import catalog validation invalid_count=$invalid');
    }
    return referenced;
  }

  @useResult
  Future<Result<void, ImportMnemonicFailure>> execute({
    required List<String> mnemonicWords,
    Language language = Language.english,
    String passphrase = '',
  }) async {
    try {
      final existing = await _secrets.find(
        words: mnemonicWords,
        language: language,
        passphrase: passphrase,
      );
      switch (existing) {
        case Err(:final failure):
          return Err(ImportMnemonicUnexpectedFailure(failure.toString()));
        case Ok(value: final secret?):
          final settings = await _settings.fetch();
          final network = settings.environment.isMainnet
              ? Network.bitcoinMainnet
              : Network.bitcoinTestnet;
          if (await isReferenced(secret.id, network)) {
            return const Err(ImportMnemonicDuplicateFailure());
          }
          return const Ok(null);
        case Ok():
          return const Ok(null);
      }
    } catch (e) {
      log.severe(
        message: 'Duplicate mnemonic check failed',
        error: e.runtimeType,
        trace: StackTrace.empty,
      );
      return Err(ImportMnemonicUnexpectedFailure(e.toString()));
    }
  }
}
