import 'package:bull_logs/src/domain/log_entry.dart';
import 'package:bull_logs/src/domain/repositories/logs_repository.dart';
import 'package:bull_logs/src/data/log_entry_model.dart';
import 'package:bull_logs/src/data/log_entry_mapper.dart';
import 'package:bull_logs/src/domain/logs_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_logs/src/domain/usecases/delete_logs_usecase.dart';
import 'package:bull_logs/src/domain/usecases/export_logs_usecase.dart';
import 'package:bull_logs/src/domain/usecases/filter_logs_usecase.dart';
import 'package:bull_logs/src/domain/usecases/load_logs_usecase.dart';
import 'package:bull_logs/src/domain/usecases/share_logs_usecase.dart';
import 'package:bull_logs/src/presentation/logs_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _LogsRepository implements LogsRepository {
  List<LogEntry> entries;
  List<LogEntry>? sharedEntries;
  LogsFailure? readFailure;

  _LogsRepository({this.entries = const []});

  @override
  Future<Result<List<LogEntry>, LogsFailure>> read() async {
    final failure = readFailure;
    return failure == null ? Ok(entries) : Err(failure);
  }

  @override
  Future<Result<void, LogsFailure>> delete() async => const Ok(null);

  @override
  Future<Result<void, LogsFailure>> share(List<LogEntry> entries) async {
    sharedEntries = entries;
    return const Ok(null);
  }

  @override
  Future<Result<bool, LogsFailure>> export(List<LogEntry> entries) async =>
      const Ok(true);
}

void main() {
  test('loads once and exposes ready entries', () async {
    final repository = _LogsRepository(
      entries: [
        LogEntryModel.fromRawLine(
          '2026-01-01T00:00:00Z\tINFO\tmessage',
        ).toDomain(),
      ],
    );
    final cubit = _buildCubit(repository);

    await cubit.load();
    expect(cubit.state.status.name, 'ready');
    expect(cubit.state.entries, hasLength(1));
    await cubit.load();
    await cubit.close();
  });

  test('applies and clears filters before sharing visible entries', () async {
    final info = LogEntryModel.fromRawLine(
      '2026-01-01T10:00:00Z\tINFO\tnetwork ready',
    ).toDomain();
    final warning = LogEntryModel.fromRawLine(
      '2026-01-02T10:00:00Z\tWARNING\tdisk warning',
    ).toDomain();
    final repository = _LogsRepository(entries: [warning, info]);
    final cubit = _buildCubit(repository);

    await cubit.load();
    cubit.setQuery('warning');
    cubit.toggleSeverity(LogSeverity.warning);
    cubit.setDateRange(DateTime(2026, 1, 2), DateTime(2026, 1, 2));
    expect(cubit.state.visibleEntries, [warning]);

    await cubit.share(cubit.state.visibleEntries);
    expect(repository.sharedEntries, [warning]);

    cubit.clearFilters();
    cubit.setDateRange(null, null);
    cubit.setQuery('');
    expect(cubit.state.visibleEntries, [warning, info]);

    cubit.toggleSeverity(LogSeverity.warning);
    cubit.toggleSeverity(LogSeverity.info);
    expect(cubit.state.severities, {LogSeverity.warning, LogSeverity.info});
    expect(cubit.state.visibleEntries, [warning, info]);
    cubit.clearFilters();

    await cubit.delete();
    expect(cubit.state.entries, isEmpty);
    expect(cubit.state.visibleEntries, isEmpty);
    await cubit.close();
  });

  test(
    'refreshes entries, reapplies filters, and retains data on error',
    () async {
      final initialWarning = LogEntryModel.fromRawLine(
        '2026-01-02T10:00:00Z\tWARNING\tinitial warning',
      ).toDomain();
      final refreshedWarning = LogEntryModel.fromRawLine(
        '2026-01-03T10:00:00Z\tWARNING\trefreshed warning',
      ).toDomain();
      final repository = _LogsRepository(entries: [initialWarning]);
      final cubit = _buildCubit(repository);

      await cubit.load();
      cubit.toggleSeverity(LogSeverity.warning);
      repository.entries = [refreshedWarning];

      final refreshResult = await cubit.refresh();
      expect(refreshResult, isA<Ok<List<LogEntry>, LogsFailure>>());
      expect(cubit.state.entries, [refreshedWarning]);
      expect(cubit.state.visibleEntries, [refreshedWarning]);
      expect(cubit.state.severities, {LogSeverity.warning});

      repository.readFailure = const LogsStorageFailure('refresh failed');
      final failedRefreshResult = await cubit.refresh();
      expect(failedRefreshResult, isA<Err<List<LogEntry>, LogsFailure>>());
      expect(cubit.state.entries, [refreshedWarning]);
      expect(cubit.state.visibleEntries, [refreshedWarning]);
      await cubit.close();
    },
  );
}

LogsCubit _buildCubit(_LogsRepository repository) => LogsCubit(
  LoadLogsUsecase(repository),
  DeleteLogsUsecase(repository),
  ShareLogsUsecase(repository),
  ExportLogsUsecase(repository),
  const FilterLogsUsecase(),
);
