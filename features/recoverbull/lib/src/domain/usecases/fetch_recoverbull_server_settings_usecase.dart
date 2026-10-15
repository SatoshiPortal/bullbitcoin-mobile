import 'package:primitives/primitives.dart';
import '../entities/recoverbull_server_settings.dart';
import '../recoverbull_failure.dart';
import '../repositories/recoverbull_repository.dart';

final class FetchRecoverBullServerSettingsUsecase {
  final RecoverBullRepository _repository;
  const FetchRecoverBullServerSettingsUsecase(this._repository);

  Future<Result<RecoverBullServerSettings, RecoverBullFailure>>
  execute() async {
    final server = await _repository.fetchUrl();
    switch (server) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        return (await _repository.fetchPermission()).map(
          (granted) => RecoverBullServerSettings(
            server: value,
            permissionGranted: granted,
          ),
        );
    }
  }
}
