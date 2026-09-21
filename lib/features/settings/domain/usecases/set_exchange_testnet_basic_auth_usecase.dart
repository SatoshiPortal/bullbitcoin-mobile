import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:meta/meta.dart';

class SetExchangeTestnetBasicAuthUsecase {
  final SettingsRepository _settingsRepository;

  const SetExchangeTestnetBasicAuthUsecase({required this._settingsRepository});

  @useResult
  Future<Result<void, SettingsFailure>> execute({
    String? username,
    String? password,
  }) async {
    final result = await _settingsRepository.setExchangeTestnetBasicAuth(
      username: username,
      password: password,
    );

    return result.mapErr(
      (failure) => SettingsStorageFailure(failure.logMessage),
    );
  }
}
