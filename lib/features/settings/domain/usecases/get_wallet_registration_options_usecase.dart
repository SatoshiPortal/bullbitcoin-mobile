import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_signing_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/wallet_registration.dart';
import 'package:bb_mobile/features/settings/domain/wallet_registration_export_builder.dart';
import 'package:meta/meta.dart';

class GetWalletRegistrationOptionsUsecase {
  final BitcoinSigningPort _bitcoinSigningPort;

  const GetWalletRegistrationOptionsUsecase({
    required this._bitcoinSigningPort,
  });

  @useResult
  Future<Result<List<WalletRegistrationOption>, SettingsFailure>> execute(
    Wallet wallet,
  ) async {
    if (!wallet.isBitcoin) return const Ok([]);
    try {
      final policyResult = await _bitcoinSigningPort.getPolicy(
        walletId: wallet.id,
      );
      switch (policyResult) {
        case Ok(:final value):
          return Ok(WalletRegistrationExportBuilder.build(wallet, value));
        case Err(:final failure):
          log.warning(
            'Failed to analyze wallet registration policy: '
            '${failure.runtimeType}',
          );
          return const Err(SettingsWalletRegistrationFailure());
      }
    } on Exception catch (error, stackTrace) {
      log.severe(
        message: 'Failed to prepare wallet registration exports',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(SettingsWalletRegistrationFailure());
    }
  }
}
