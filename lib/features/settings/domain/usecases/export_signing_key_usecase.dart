import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/signing_key_account_session.dart';
import 'package:bb_mobile/core/utils/bip48_derivation.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';

class ExportSigningKeyUsecase {
  final GetDefaultSeedUsecase _getDefaultSeedUsecase;
  final GetSettingsUsecase _getSettingsUsecase;
  final SigningKeyAccountSession _accountSession;
  final LabelsFacade _labelsFacade;

  ExportSigningKeyUsecase(
    this._accountSession, {
    required this._getDefaultSeedUsecase,
    required this._getSettingsUsecase,
    required this._labelsFacade,
  });

  @useResult
  Future<
    Result<
      ({
        int account,
        String descriptorKey,
        bool isReserved,
        int? markedAccount,
        bool descriptionSaved,
      }),
      SettingsFailure
    >
  >
  execute({int? account, bool markUsed = false, String? description}) async {
    if (markUsed &&
        (account == null ||
            description == null ||
            description.trim().isEmpty)) {
      return const Err(SettingsSigningKeyExportFailure());
    }
    final requestId = _accountSession.beginRequest();
    try {
      final settings = await _getSettingsUsecase.execute();
      final seed = await _getDefaultSeedUsecase.execute(
        environment: settings.environment,
      );
      final isTestnet = settings.environment.isTestnet;
      final coinType = isTestnet ? 1 : 0;
      final network = isTestnet
          ? Network.bitcoinTestnet
          : Network.bitcoinMainnet;
      final usedXpub = markUsed
          ? Bip32Derivation.deriveXpub(
              seedBytes: seed.bytes,
              derivationPath: Bip48Derivation.path(
                coinType: coinType,
                account: account!,
              ),
              network: network,
            )
          : null;
      final selectionResult = await _accountSession.select(
        requestId: requestId,
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
      final derivationPath = Bip48Derivation.path(
        coinType: coinType,
        account: selection.account,
      );
      final xpub = Bip32Derivation.deriveXpub(
        seedBytes: seed.bytes,
        derivationPath: derivationPath,
        network: network,
      );
      final originPath = derivationPath.substring(2).replaceAll("'", 'h');

      // A description failure does not undo the successful reservation.
      final descriptionSaved =
          usedXpub == null ||
          await _labelsFacade.store(
                NewLabel(
                  type: LabelType.extendedPublicKey,
                  reference: usedXpub,
                  label: description!.trim(),
                  origin:
                      '[${seed.masterFingerprint.toLowerCase()}/'
                      '${Bip48Derivation.path(coinType: coinType, account: account!).substring(2)}]',
                ),
              )
              is Ok;

      return Ok((
        account: selection.account,
        descriptorKey:
            '[${seed.masterFingerprint.toLowerCase()}/$originPath]$xpub',
        isReserved: selection.isReserved,
        markedAccount: selection.markedAccount,
        descriptionSaved: descriptionSaved,
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
