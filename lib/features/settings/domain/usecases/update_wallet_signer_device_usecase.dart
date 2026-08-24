import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_signer_device_port.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:meta/meta.dart';

class UpdateWalletSignerDeviceUsecase {
  final WalletSignerDevicePort _walletSignerDevicePort;

  const UpdateWalletSignerDeviceUsecase({
    required this._walletSignerDevicePort,
  });

  @useResult
  Future<Result<Wallet, SettingsFailure>> execute({
    required String walletId,
    required String signerId,
    required SignerDeviceEntity? signerDevice,
  }) async {
    try {
      final wallet = await _walletSignerDevicePort.updateSignerDevice(
        walletId: walletId,
        signerId: signerId,
        signerDevice: signerDevice,
      );
      return Ok(wallet);
    } on Exception catch (error, stackTrace) {
      log.severe(
        message: 'Failed to update wallet signer device',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(SettingsStorageFailure());
    }
  }
}
