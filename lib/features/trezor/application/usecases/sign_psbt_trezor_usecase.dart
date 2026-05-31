import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/trezor/application/application_errors.dart';
import 'package:bb_mobile/features/trezor/application/trezor_device_repository.dart';
import 'package:bb_mobile/features/trezor/domain/entities/trezor_signed_psbt.dart';

class SignPsbtTrezorUsecase {
  final TrezorDeviceRepository _repository;

  SignPsbtTrezorUsecase({required TrezorDeviceRepository repository})
    : _repository = repository;

  Future<TrezorSignedPsbt> execute({
    required String psbtBase64,
    required bool isTestnet,
    required ScriptType scriptType,
  }) async {
    try {
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
