import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/trezor/domain/repositories/trezor_device_repository.dart';
import 'package:bb_mobile/features/trezor/domain/trezor_error.dart';

class VerifyAddressTrezorUsecase {
  final TrezorDeviceRepository _repository;

  VerifyAddressTrezorUsecase({required this._repository});

  /// Asks Trezor Suite to display the expected address on the device. The
  /// device derives the address locally from the given derivation path and
  /// shows it for the user to compare against the in-app QR. The user must
  /// physically confirm on the device for the call to resolve `true`.
  ///
  /// Returns `true` on user confirmation, `false` on user rejection (the
  /// underlying error is captured at the application-error boundary).
  Future<bool> execute({
    required String address,
    required String derivationPath,
    required ScriptType scriptType,
    required bool isTestnet,
  }) async {
    try {
      // 60s safety net for the case Trezor Suite handles an error in its
      // own UI without emitting a callback URI back to the app (e.g. some
      // Failure_DataError paths). For callbacks that DO arrive with
      // success=false, the package now surfaces errors immediately via
      // TrezorCallbackException — no hang.
      return await _repository
          .verifyAddress(
            address: address,
            derivationPath: derivationPath,
            scriptType: scriptType,
            isTestnet: isTestnet,
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw const TrezorError.timeout(),
          );
    } on TrezorError {
      rethrow;
    } catch (e) {
      throw TrezorError.unknown(e.toString());
    }
  }
}
