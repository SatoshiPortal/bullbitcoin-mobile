import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/signing_key_account_session.dart';
import 'package:bb_mobile/features/settings/domain/used_signing_key_account.dart';
import 'package:bb_mobile/features/settings/domain/usecases/sync_used_signing_key_accounts_usecase.dart';
import 'package:bb_mobile/core/utils/bip48_derivation.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';

class ExportSigningKeyUsecase {
  final GetDefaultSeedUsecase _getDefaultSeedUsecase;
  final GetSettingsUsecase _getSettingsUsecase;
  final SigningKeyAccountSession _accountSession;
  final LabelsFacade _labelsFacade;
  final SyncUsedSigningKeyAccountsUsecase _syncUsedAccounts;

  ExportSigningKeyUsecase(
    this._accountSession, {
    required this._getDefaultSeedUsecase,
    required this._getSettingsUsecase,
    required this._labelsFacade,
    required this._syncUsedAccounts,
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
        List<UsedSigningKeyAccount> usedAccounts,
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
      // Repair restored reservations before claiming the next export account.
      var usedResult = await _syncUsedAccounts.execute(
        seedFingerprint: seed.masterFingerprint,
        coinType: coinType,
      );
      if (usedResult case Err(:final failure)) return Err(failure);
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
      String origin(int account) {
        final path = Bip48Derivation.path(
          coinType: coinType,
          account: account,
        ).substring(2).replaceAll("'", 'h');
        return '[${seed.masterFingerprint.toLowerCase()}/$path]';
      }

      // A description failure does not undo the successful reservation.
      final descriptionSaved =
          usedXpub == null ||
          await _labelsFacade.store(
                NewLabel(
                  type: LabelType.extendedPublicKey,
                  reference: usedXpub,
                  label: description!.trim(),
                  origin: origin(account!),
                ),
              )
              is Ok;

      if (markUsed) {
        usedResult = await _syncUsedAccounts.execute(
          seedFingerprint: seed.masterFingerprint,
          coinType: coinType,
        );
      }
      if (usedResult case Err(:final failure)) return Err(failure);
      return Ok((
        account: selection.account,
        descriptorKey: '${origin(selection.account)}$xpub',
        isReserved: selection.isReserved,
        markedAccount: selection.markedAccount,
        descriptionSaved: descriptionSaved,
        usedAccounts: (usedResult as Ok).value,
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
