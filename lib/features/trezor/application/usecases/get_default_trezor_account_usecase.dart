import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/trezor/application/application_errors.dart';
import 'package:bb_mobile/features/trezor/application/trezor_device_repository.dart';
import 'package:bb_mobile/features/trezor/domain/entities/trezor_account.dart';

class GetDefaultTrezorAccountUsecase {
  final TrezorDeviceRepository _repository;

  GetDefaultTrezorAccountUsecase({required TrezorDeviceRepository repository})
    : _repository = repository;

  Future<TrezorAccount> execute({
    required ScriptType scriptType,
    required bool isTestnet,
  }) async {
    try {
      // 5min safety net for user-attention scenarios — granting
      // permissions and exporting in Trezor Suite can take a while
      // during first-time setup. The package surfaces callback errors
      // (user rejected, validation) immediately as typed exceptions;
      // this guard only catches "no callback ever arrived" cases
      // (user walked away, Suite force-quit, etc.).
      return await _repository
          .getDefaultAccount(scriptType: scriptType, isTestnet: isTestnet)
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
