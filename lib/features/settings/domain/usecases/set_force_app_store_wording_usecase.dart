import 'package:bb_mobile/features/settings/domain/repositories/app_store_wording_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class SetForceAppStoreWordingUsecase {
  final AppStoreWordingRepository _repository;

  const SetForceAppStoreWordingUsecase({required this._repository});

  @useResult
  Future<Result<void, SettingsFailure>> execute(bool forced) =>
      _repository.setForced(forced);
}
