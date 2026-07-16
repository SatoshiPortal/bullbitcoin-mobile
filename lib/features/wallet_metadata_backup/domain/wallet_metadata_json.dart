import 'dart:collection';
import 'dart:convert';

import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_limits.dart';

String walletMetadataValidateString(
  String value, {
  required String name,
  bool allowEmpty = true,
}) {
  if (!allowEmpty && value.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
  if (utf8.encode(value).length > WalletMetadataBackupLimits.maxStringBytes) {
    throw ArgumentError.value(value, name, 'exceeds the UTF-8 byte limit');
  }
  return value;
}

Object? walletMetadataFreezeJsonValue(Object? value, {int depth = 0}) {
  if (depth > WalletMetadataBackupLimits.maxJsonDepth) {
    throw ArgumentError.value(depth, 'depth', 'JSON nesting is too deep');
  }
  if (value == null || value is bool) return value;
  if (value is int) {
    if (value < WalletMetadataBackupLimits.minSignedInt64 ||
        value > WalletMetadataBackupLimits.maxSignedInt64) {
      throw ArgumentError.value(value, 'value', 'integer is outside int64');
    }
    return value;
  }
  if (value is String) {
    return walletMetadataValidateString(value, name: 'JSON string');
  }
  if (value is List) {
    if (value.length > WalletMetadataBackupLimits.maxJsonCollectionLength) {
      throw ArgumentError.value(value.length, 'value', 'JSON list is too long');
    }
    return List<Object?>.unmodifiable(
      value.map(
        (item) => walletMetadataFreezeJsonValue(item, depth: depth + 1),
      ),
    );
  }
  if (value is Map) {
    if (value.length > WalletMetadataBackupLimits.maxJsonCollectionLength) {
      throw ArgumentError.value(
        value.length,
        'value',
        'JSON object is too large',
      );
    }
    final sorted = SplayTreeMap<String, Object?>();
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw ArgumentError.value(
          key,
          'value',
          'JSON object keys must be strings',
        );
      }
      walletMetadataValidateString(key, name: 'JSON object key');
      sorted[key] = walletMetadataFreezeJsonValue(
        entry.value,
        depth: depth + 1,
      );
    }
    return UnmodifiableMapView<String, Object?>(sorted);
  }
  throw ArgumentError.value(
    value,
    'value',
    'must be a JSON null, boolean, int64, string, list, or object',
  );
}

Map<String, Object?> walletMetadataFreezeJsonObject(
  Map<String, Object?> value,
) {
  return walletMetadataFreezeJsonValue(value) as Map<String, Object?>;
}

String walletMetadataCanonicalJsonEncode(Object? value) {
  return jsonEncode(walletMetadataFreezeJsonValue(value));
}
