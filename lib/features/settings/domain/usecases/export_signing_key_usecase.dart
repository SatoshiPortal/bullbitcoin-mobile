import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/signing_key_account_session.dart';
import 'package:bb_mobile/features/settings/domain/signing_key_derivation.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class ExportSigningKeyUsecase {
  final GetDefaultSeedUsecase _getDefaultSeedUsecase;
  final GetSettingsUsecase _getSettingsUsecase;
  final SigningKeyAccountSession _accountSession;

  ExportSigningKeyUsecase(
    this._accountSession, {
    required this._getDefaultSeedUsecase,
    required this._getSettingsUsecase,
  });

  @useResult
  Future<
    Result<
      ({
        int account,
        String descriptorKey,
        bool isReserved,
        int? markedAccount,
      }),
      SettingsFailure
    >
  >
  execute({int? account, bool markUsed = false}) async {
    try {
      final settings = await _getSettingsUsecase.execute();
      final seed = await _getDefaultSeedUsecase.execute(
        environment: settings.environment,
      );
      final isTestnet = settings.environment.isTestnet;
      final coinType = isTestnet ? 1 : 0;
      final selectionResult = await _accountSession.select(
        seedFingerprint: seed.masterFingerprint,
        coinType: coinType,
        account: account,
        markUsed: markUsed,
      );
      final SigningKeyAccountSelection selection;
      switch (selectionResult) {
        case Ok(:final value):
          selection = value;
        case Err():
          return const Err(SettingsSigningKeyExportFailure());
      }
      final derivationPath = SigningKeyDerivation.path(
        isTestnet: isTestnet,
        account: selection.account,
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

      return Ok((
        account: selection.account,
        descriptorKey:
            '[${seed.masterFingerprint.toLowerCase()}/$originPath]$xpub',
        isReserved: selection.isReserved,
        markedAccount: selection.markedAccount,
      ));
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
