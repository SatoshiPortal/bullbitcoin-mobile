import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class SecureStorageDumpUsecase {
  final KeyValueStorageDatasource<String> _secureStorage;

  SecureStorageDumpUsecase({
    required KeyValueStorageDatasource<String> secureStorage,
  }) : _secureStorage = secureStorage;

  Future<void> execute() async {
    try {
      final allEntries = await _secureStorage.getAll();

      if (allEntries.isEmpty) {
        log.info('SECURE_STORAGE_DUMP: No entries found in secure storage');
        return;
      }

      log.info(
        'SECURE_STORAGE_DUMP: Found ${allEntries.length} entries in secure storage',
      );
      log.info('SECURE_STORAGE_DUMP: ========================================');

      // Sort keys for consistent output
      final sortedKeys = allEntries.keys.toList()..sort();

      for (final key in sortedKeys) {
        final value = allEntries[key];

        // Mask sensitive values for security (show only first/last few chars)
        String displayValue;
        if (value == null || value.isEmpty) {
          displayValue = '<empty>';
        } else if (value.length <= 8) {
          displayValue = '***${value.substring(value.length - 2)}';
        } else {
          // Show first 4 and last 4 characters, mask the middle
          final first = value.substring(0, 4);
          final last = value.substring(value.length - 4);
          final maskedLength = value.length - 8;
          displayValue =
              '$first${"*" * maskedLength}$last (length: ${value.length})';
        }

        log.info('SECURE_STORAGE_DUMP:   Key: "$key" => Value: $displayValue');
      }

      log.info('SECURE_STORAGE_DUMP: ========================================');
    } catch (e) {
      log.severe(
        message: 'SECURE_STORAGE_DUMP: Failed to dump secure storage contents',
        error: e,
        trace: StackTrace.current,
      );
    }
  }
}
