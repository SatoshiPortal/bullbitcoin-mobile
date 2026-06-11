import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/trezor/application/application_errors.dart';
import 'package:bb_mobile/features/trezor/application/trezor_device_repository.dart';

class SignPsbtTrezorUsecase {
  final TrezorDeviceRepository _repository;

  SignPsbtTrezorUsecase({required this._repository});

  Future<String> execute({
    required String psbtBase64,
    required bool isTestnet,
    required ScriptType scriptType,
  }) async {
    try {
      // 5min safety net for user-attention scenarios — reviewing
      // destination, amount, and fee on device can take a few minutes for
      // careful users. For callbacks that DO arrive with success=false
      // (user rejected, validation error), the package now surfaces errors
      // immediately via TrezorCallbackException; this guard only catches
      // cases where no callback arrives at all (user walked away, Suite
      // force-quit, etc.).
      return await _repository
          .signPsbt(
            psbtBase64: psbtBase64,
            isTestnet: isTestnet,
            scriptType: scriptType,
          )
          .timeout(
            const Duration(minutes: 5),
            onTimeout: () => throw const TrezorApplicationError.timeout(),
          );
    } on TrezorApplicationError {
      rethrow;
    } catch (e) {
      throw TrezorApplicationError.unknown(e.toString());
    }
  }
}
