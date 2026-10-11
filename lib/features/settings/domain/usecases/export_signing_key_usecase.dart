import 'package:primitives/primitives.dart' show Fingerprint, BitcoinNetwork;
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/signing_key_account_session.dart';
import 'package:bb_mobile/features/settings/domain/used_signing_key_account.dart';
import 'package:bb_mobile/features/settings/domain/usecases/sync_used_signing_key_accounts_usecase.dart';
import 'package:bb_mobile/core/utils/bip48_derivation.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';

class ExportSigningKeyUsecase {
  final WalletRepository _wallets;
  final Secrets _secrets;
  final GetSettingsUsecase _getSettingsUsecase;
  final SigningKeyAccountSession _accountSession;
  final LabelsFacade _labelsFacade;
  final SyncUsedSigningKeyAccountsUsecase _syncUsedAccounts;

  ExportSigningKeyUsecase(
    this._accountSession, {
    required WalletRepository walletRepository,
    required this._secrets,
    required this._getSettingsUsecase,
    required this._labelsFacade,
    required this._syncUsedAccounts,
  }) : _wallets = walletRepository;

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
      final wallets = await _wallets.getWallets(
        environment: settings.environment,
        onlyDefaults: true,
        onlyBitcoin: true,
      );
      final fingerprint = switch (wallets) {
        Ok(:final value) => value.firstOrNull?.singleLocalSeedFingerprint,
        Err() => null,
      };
      final id = Fingerprint.tryParse(fingerprint ?? '');
      if (id == null) return const Err(SettingsSigningKeyExportFailure());
      final Secret secret;
      switch (await _secrets.retainCanonical(id)) {
        case Ok(:final value):
          secret = value;
        case Err():
          return const Err(SettingsSigningKeyExportFailure());
      }
      final isTestnet = settings.environment.isTestnet;
      final coinType = isTestnet ? 1 : 0;
      // Repair restored reservations before claiming the next export account.
      var usedResult = await _syncUsedAccounts.execute(
        seedFingerprint: secret.id.hex,
        coinType: coinType,
      );
      if (usedResult case Err(:final failure)) return Err(failure);
      final network = isTestnet
          ? BitcoinNetwork.testnet
          : BitcoinNetwork.mainnet;
      String? usedXpub;
      final usedAccount = markUsed ? account : null;
      if (usedAccount != null) {
        switch (await secret.derive.account(
          derivationPath: Bip48Derivation.path(
            coinType: coinType,
            account: usedAccount,
          ),
          network: network,
        )) {
          case Ok(:final value):
            usedXpub = value.xpub;
          case Err():
            return const Err(SettingsSigningKeyExportFailure());
        }
      }
      final selectionResult = await _accountSession.select(
        requestId: requestId,
        seedFingerprint: secret.id.hex,
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
      final PublicAccountKey key;
      switch (await secret.derive.account(
        derivationPath: derivationPath,
        network: network,
      )) {
        case Ok(:final value):
          key = value;
        case Err():
          return const Err(SettingsSigningKeyExportFailure());
      }
      String origin(int account) {
        final path = Bip48Derivation.path(
          coinType: coinType,
          account: account,
        ).substring(2).replaceAll("'", 'h');
        return '[${secret.id.hex.toLowerCase()}/$path]';
      }

      // A description failure does not undo the successful reservation.
      final descriptionSaved =
          usedXpub == null ||
          usedAccount == null ||
          description == null ||
          await _labelsFacade.store(
                NewLabel(
                  type: LabelType.extendedPublicKey,
                  reference: usedXpub,
                  label: description.trim(),
                  origin: origin(usedAccount),
                ),
              )
              is Ok;

      if (markUsed) {
        usedResult = await _syncUsedAccounts.execute(
          seedFingerprint: secret.id.hex,
          coinType: coinType,
        );
      }
      if (usedResult case Err(:final failure)) return Err(failure);
      return Ok((
        account: selection.account,
        descriptorKey: '${origin(selection.account)}${key.xpub}',
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
