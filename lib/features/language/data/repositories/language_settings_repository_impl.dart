import 'package:bb_mobile/core/data/datasources/key_value_storage_data_source.dart';
import 'package:bb_mobile/features/language/domain/entities/language.dart';
import 'package:bb_mobile/features/language/domain/repositories/language_settings_repository.dart';

class LanguageSettingsRepositoryImpl implements LanguageSettingsRepository {
  static const _key = 'language';

  final KeyValueStorageDataSource<String> _storage;

  LanguageSettingsRepositoryImpl({
    required KeyValueStorageDataSource<String> storage,
  }) : _storage = storage;

  @override
  Future<void> setLanguage(Language language) async {
    return _storage.saveValue(key: _key, value: language.name);
  }

  @override
  Future<Language?> getLanguage() async {
    final languageName = await _storage.getValue(_key);
    if (languageName == null) {
      return null;
    }
    final language = Language.fromName(languageName);
    return language;
  }
}
