import 'package:bull_logs/src/data/log_entry_mapper.dart';
import 'package:bull_logs/src/data/log_entry_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves second precision for every supported timestamp width', () {
    final values = [
      '2026-01-01T12:34:56.123456Z',
      '2026-01-01T12:34:56.123Z',
      '2026-01-01T12:34:56Z',
    ];
    final entries = values
        .map(
          (timestamp) =>
              LogEntryModel.fromRawLine('$timestamp\tINFO\tmessage').toDomain(),
        )
        .toList();

    expect(entries.map((entry) => entry.timestamp?.toIso8601String()), [
      '2026-01-01T12:34:56.123456Z',
      '2026-01-01T12:34:56.123Z',
      '2026-01-01T12:34:56.000Z',
    ]);
    expect(entries.map((entry) => entry.displayText.split(' | ').first), [
      '2026-01-01T12:34:56Z',
      '2026-01-01T12:34:56Z',
      '2026-01-01T12:34:56Z',
    ]);
    expect(
      entries.map((entry) => entry.rawLine),
      values.map((value) => '$value\tINFO\tmessage'),
    );
  });
}
