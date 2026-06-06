import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/trezor/application/application_errors.dart';
import 'package:bb_mobile/features/trezor/application/trezor_device_repository.dart';
import 'package:bb_mobile/features/trezor/domain/entities/trezor_account.dart';

class GetTrezorAccountsUsecase {
  final TrezorDeviceRepository _repository;

  GetTrezorAccountsUsecase({required TrezorDeviceRepository repository})
    : _repository = repository;

  Future<List<TrezorAccount>> execute({
    required int startIndex,
    required int count,
    required ScriptType scriptType,
    required bool isTestnet,
  }) async {
    try {
      // 5min safety net for user-attention scenarios — granting
      // permissions and exporting accounts in Trezor Suite can take a
      // while during first-time setup. For callbacks that DO arrive with
      // success=false (user rejected, validation error), the package now
      // surfaces errors immediately via TrezorCallbackException; this
      // guard only catches cases where no callback arrives at all (user
      // walked away, Suite force-quit, etc.).
      return await _repository
          .getAccounts(
            startIndex: startIndex,
            count: count,
            scriptType: scriptType,
            isTestnet: isTestnet,
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
