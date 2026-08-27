import 'package:bb_mobile/features/settings/data/log_entry_mapper.dart';
import 'package:bb_mobile/features/settings/data/models/log_entry_model.dart';
import 'package:bb_mobile/features/settings/domain/log_entry.dart';
import 'package:bb_mobile/features/settings/domain/usecases/filter_logs_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

LogEntry _entry(String line) => LogEntryModel.fromRawLine(line).toDomain();

void main() {
  final entries = [
    _entry('2026-01-01T10:00:00.000Z\tWARNING\tDisk warning'),
    _entry('2026-01-02T10:00:00.000Z\tINFO\tNetwork ready'),
    _entry('not-a-date\tSEVERE\tNetwork failure'),
  ];

  test('filters by query, severity, and inclusive date range', () {
    final result = const FilterLogsUsecase().execute(
      entries,
      query: 'NETWORK',
      severities: {LogSeverity.info},
      startDate: DateTime(2026, 1, 2),
      endDate: DateTime(2026, 1, 2),
    );

    expect(result.map((entry) => entry.rawLine), [entries[1].rawLine]);
  });

  test('excludes entries with invalid dates when a date filter is active', () {
    final result = const FilterLogsUsecase().execute(
      entries,
      startDate: DateTime(2026, 1, 1),
    );

    expect(result, hasLength(2));
    expect(result.any((entry) => entry.timestamp == null), isFalse);
  });

  test('combines selected severities and treats an empty set as all', () {
    final usecase = const FilterLogsUsecase();

    expect(
      usecase.execute(
        entries,
        severities: {LogSeverity.warning, LogSeverity.info},
      ),
      [entries[0], entries[1]],
    );
    expect(usecase.execute(entries), entries);
  });
}
