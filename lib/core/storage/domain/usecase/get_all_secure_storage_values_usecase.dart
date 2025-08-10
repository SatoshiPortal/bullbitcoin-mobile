import 'package:bb_mobile/core/storage/data/repository/secure_storage_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class GetAllSecureStorageValuesUsecase {
  final SecureStorageRepository _repository;

  GetAllSecureStorageValuesUsecase(this._repository);

  Future<Map<String, String>> call() async {
    try {
      final result = await _repository.getAllKeyValues();
      return result;
    } catch (error) {
      log.severe(
        'Error occurred while fetching secure storage values',
        error: error,
      );
      rethrow;
    }
  }
}
