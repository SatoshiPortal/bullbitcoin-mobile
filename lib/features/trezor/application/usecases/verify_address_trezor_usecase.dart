import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/trezor/application/application_errors.dart';
import 'package:bb_mobile/features/trezor/application/trezor_device_repository.dart';

class VerifyAddressTrezorUsecase {
  final TrezorDeviceRepository _repository;

  VerifyAddressTrezorUsecase({required TrezorDeviceRepository repository})
    : _repository = repository;

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
  }) async {
    try {
      // verify-address is a single yes/no confirmation,
      // and Trezor Suite doesn't always send a callback URI on Failure_DataError,
      // it just shows its own error panel. Without this guard the cubit would hang in
      // `waitingForSuite` for 5 minutes after a rejected request.
      return await _repository
          .verifyAddress(
            address: address,
            derivationPath: derivationPath,
            scriptType: scriptType,
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw const TrezorApplicationError.timeout(),
          );
    } on TrezorApplicationError {
      rethrow;
    } catch (e) {
      throw TrezorApplicationError.unknown(e.toString());
    }
  }
}
