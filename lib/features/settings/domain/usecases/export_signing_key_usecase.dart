import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/signing_key_derivation.dart';
import 'package:meta/meta.dart';

class ExportSigningKeyUsecase {
  final GetDefaultSeedUsecase _getDefaultSeedUsecase;
  final GetSettingsUsecase _getSettingsUsecase;

  const ExportSigningKeyUsecase({
    required this._getDefaultSeedUsecase,
    required this._getSettingsUsecase,
  });

  @useResult
  Future<Result<String, SettingsFailure>> execute({
    required int account,
  }) async {
    try {
      final settings = await _getSettingsUsecase.execute();
      final seed = await _getDefaultSeedUsecase.execute(
        environment: settings.environment,
      );
      final isTestnet = settings.environment.isTestnet;
      final derivationPath = SigningKeyDerivation.path(
        isTestnet: isTestnet,
        account: account,
      );
      final network = isTestnet
          ? Network.bitcoinTestnet
          : Network.bitcoinMainnet;
      final xpub = Bip32Derivation.deriveXpub(
        seedBytes: seed.bytes,
        derivationPath: derivationPath,
        network: network,
      );
      final originPath = derivationPath.substring(2).replaceAll("'", 'h');

      return Ok('[${seed.masterFingerprint.toLowerCase()}/$originPath]$xpub');
    } on Exception catch (error, stackTrace) {
      log.severe(
        message: 'Failed to export signing key',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(SettingsSigningKeyExportFailure());
    }
  }
}
