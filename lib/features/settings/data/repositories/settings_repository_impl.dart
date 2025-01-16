import 'package:bb_mobile/core/datasources/key_value_storage_data_source.dart';
import 'package:bb_mobile/features/settings/domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final KeyValueStorageDataSource _dataSource;

  const SettingsRepositoryImpl({
    required KeyValueStorageDataSource dataSource,
  }) : _dataSource = dataSource;

  @override
  Future<String> getDefaultCurrency() {
    // TODO: implement getDefaultCurrency
    throw UnimplementedError();
  }

  @override
  Future<void> setDefaultCurrency(String currencyCode) {
    // TODO: implement setDefaultCurrency
    throw UnimplementedError();
  }
}
