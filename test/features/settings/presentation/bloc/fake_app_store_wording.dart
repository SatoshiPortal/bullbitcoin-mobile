import 'package:bb_mobile/features/settings/domain/repositories/app_store_wording_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_force_app_store_wording_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_force_app_store_wording_usecase.dart';
import 'package:primitives/primitives.dart';

/// In-memory [AppStoreWordingRepository] for cubit tests.
class FakeAppStoreWordingRepository implements AppStoreWordingRepository {
  FakeAppStoreWordingRepository({this.forced = false, this.failWrites = false});

  bool forced;
  bool failWrites;

  @override
  Future<Result<bool, SettingsFailure>> isForced() async => Ok(forced);

  @override
  Future<Result<void, SettingsFailure>> setForced(bool value) async {
    if (failWrites) return const Err(SettingsStorageFailure());
    forced = value;
    return const Ok(null);
  }
}

GetForceAppStoreWordingUsecase getForceWording(
  FakeAppStoreWordingRepository repository,
) => GetForceAppStoreWordingUsecase(repository: repository);

SetForceAppStoreWordingUsecase setForceWording(
  FakeAppStoreWordingRepository repository,
) => SetForceAppStoreWordingUsecase(repository: repository);
