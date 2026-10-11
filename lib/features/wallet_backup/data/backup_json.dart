import 'dart:convert';

// Used by the snapshot and BULL response boundaries, within this feature only.
Map<String, dynamic> readBackupJson(String source) {
  _checkDepth(source);
  final value = jsonDecode(source);
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected backup object');
  }
  return value;
}

// The supported schema is less than 16 levels deep. Reject hostile nesting
// before dart:convert recurses; quoted brackets do not count as structure.
void _checkDepth(String source) {
  var depth = 0;
  var quoted = false;
  var escaped = false;
  for (final character in source.codeUnits) {
    if (quoted) {
      if (escaped) {
        escaped = false;
      } else if (character == 92) {
        escaped = true;
      } else if (character == 34) {
        quoted = false;
      }
    } else if (character == 34) {
      quoted = true;
    } else if (character == 123 || character == 91) {
      if (++depth > 16) {
        throw const FormatException('Snapshot nesting exceeds schema');
      }
    } else if (character == 125 || character == 93) {
      if (--depth < 0) {
        throw const FormatException('Invalid snapshot structure');
      }
    }
  }
}
