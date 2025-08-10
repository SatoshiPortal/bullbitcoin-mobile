import 'package:bb_mobile/core/storage/data/repository/secure_storage_repository.dart';

class GetAllSecureStorageValuesUsecase {
  final SecureStorageRepository _repository;

  GetAllSecureStorageValuesUsecase(this._repository);

  Future<Map<String, String>> call() async {
    return await _repository.getAllKeyValues();
  }
}
