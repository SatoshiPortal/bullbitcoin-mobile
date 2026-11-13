import 'package:bb_mobile/features/settings/domain/repositories/app_store_wording_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class GetForceAppStoreWordingUsecase {
  final AppStoreWordingRepository _repository;

  const GetForceAppStoreWordingUsecase({required this._repository});

  @useResult
  Future<Result<bool, SettingsFailure>> execute() => _repository.isForced();
}
