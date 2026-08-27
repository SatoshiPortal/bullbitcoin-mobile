import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/data/datasources/export_logs_datasource.dart';
import 'package:bb_mobile/features/settings/data/datasources/logger_logs_datasource.dart';
import 'package:bb_mobile/features/settings/data/datasources/share_logs_datasource.dart';
import 'package:bb_mobile/features/settings/data/logs_repository_impl.dart';
import 'package:bb_mobile/features/settings/domain/log_entry.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'maps logs newest-first and preserves raw TSV lines for export',
    () async {
      const newest = '2026-01-02T00:00:00.000Z\tWARNING\tnew';
      const oldest = '2026-01-01T00:00:00.000Z\tFINE\told';
      List<String>? exported;
      final repository = LogsRepositoryImpl(
        _FakeLoggerDatasource([oldest, newest]),
        _FakeShareDatasource(),
        _FakeExportDatasource((lines) async {
          exported = lines;
          return true;
        }),
      );

      final result = await repository.read();
      expect(result, isA<Ok<List<LogEntry>, SettingsFailure>>());
      final entries = (result as Ok<List<LogEntry>, SettingsFailure>).value;
      expect(entries.map((entry) => entry.rawLine), [newest, oldest]);

      await repository.export(entries);
      expect(exported, [newest, oldest]);
    },
  );

  test('prepends a fresh diagnostic context to share and export', () async {
    const rawLine = '2026-01-02T00:00:00.000Z\tWARNING\tnew';
    const contextLine =
        '2026-01-02T00:00:01.000Z\tCONFIG\t{"context_version":1}';
    List<String>? shared;
    List<String>? exported;
    final repository = LogsRepositoryImpl(
      _FakeLoggerDatasource(const [], contextLine: contextLine),
      _FakeShareDatasource((lines) async => shared = lines),
      _FakeExportDatasource((lines) async {
        exported = lines;
        return true;
      }),
    );
    final entry = LogEntry(
      rawLine: rawLine,
      timestamp: DateTime(2026, 1, 2),
      rawLevel: 'WARNING',
      severity: LogSeverity.warning,
      displayText: 'new',
    );

    await repository.share([entry]);
    await repository.export([entry]);

    expect(shared, [contextLine, rawLine]);
    expect(exported, [contextLine, rawLine]);
  });
}

class _FakeLoggerDatasource implements LoggerLogsDatasource {
  final List<String> lines;
  final String? contextLine;

  _FakeLoggerDatasource(this.lines, {this.contextLine});

  @override
  Future<List<String>> read() async => lines;

  @override
  Future<void> delete() async {}

  @override
  Future<String?> currentDiagnosticLogLine() async => contextLine;
}

class _FakeShareDatasource implements ShareLogsDatasource {
  final Future<void> Function(List<String>)? callback;

  _FakeShareDatasource([this.callback]);

  @override
  Future<void> share(List<String> lines) async => callback?.call(lines);
}

class _FakeExportDatasource implements ExportLogsDatasource {
  final Future<bool> Function(List<String>) callback;

  _FakeExportDatasource(this.callback);

  @override
  Future<bool> export(List<String> lines) => callback(lines);
}
