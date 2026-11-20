import 'package:bbx_api/src/bbx_api_exception.dart';

/// Reads a wire value as [T], or throws a [BbxApiFormatException] naming
/// [field] without quoting the value.
T read<T>(Object? value, String field) {
  if (value is T) return value;
  throw BbxApiFormatException('invalid $field');
}

/// Reads an optional JSON array of objects; a missing array is empty.
List<T> readList<T>(
  Object? value,
  String field,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (value == null) return const [];
  return [
    for (final element in read<List<dynamic>>(value, field))
      fromJson(read<Map<String, dynamic>>(element, field)),
  ];
}
