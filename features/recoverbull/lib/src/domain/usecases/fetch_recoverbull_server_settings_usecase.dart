import '../entities/recoverbull_server_settings.dart';
import '../repositories/recoverbull_repository.dart';

final class FetchRecoverBullServerSettingsUsecase {
  final RecoverBullRepository _repository;

  const FetchRecoverBullServerSettingsUsecase(this._repository);

  Future<RecoverBullServerSettings> execute() async =>
      RecoverBullServerSettings(
        server: await _repository.fetchUrl(),
        permissionGranted: await _repository.fetchPermission(),
      );
}
