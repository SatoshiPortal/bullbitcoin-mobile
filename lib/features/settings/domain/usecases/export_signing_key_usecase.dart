import 'package:primitives/primitives.dart' show Fingerprint, BitcoinNetwork;
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/signing_key_account_session.dart';
import 'package:bb_mobile/core/utils/bip48_derivation.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:secrets/secrets.dart';

class ExportSigningKeyUsecase {
  final WalletRepository _wallets;
  final Secrets _secrets;
  final GetSettingsUsecase _getSettingsUsecase;
  final SigningKeyAccountSession _accountSession;

  ExportSigningKeyUsecase(
    this._accountSession, {
    required WalletRepository walletRepository,
    required this._secrets,
    required this._getSettingsUsecase,
  }) : _wallets = walletRepository;

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
      final derived = await secret.derive.account(
        derivationPath: derivationPath,
        network: isTestnet ? BitcoinNetwork.testnet : BitcoinNetwork.mainnet,
      );
      final PublicAccountKey key;
      switch (derived) {
        case Ok(:final value):
          key = value;
        case Err():
          return const Err(SettingsSigningKeyExportFailure());
      }
      final originPath = derivationPath.substring(2).replaceAll("'", 'h');

      return Ok((
        account: selection.account,
        descriptorKey: '[${key.fingerprint.hex}/$originPath]${key.xpub}',
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
