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
  }) async {
    try {
      return await _repository
          .getAccounts(
            startIndex: startIndex,
            count: count,
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
