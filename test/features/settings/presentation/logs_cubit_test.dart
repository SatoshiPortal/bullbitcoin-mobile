import 'package:bb_mobile/features/settings/domain/log_entry.dart';
import 'package:bb_mobile/features/settings/domain/repositories/logs_repository.dart';
import 'package:bb_mobile/features/settings/data/models/log_entry_model.dart';
import 'package:bb_mobile/features/settings/data/log_entry_mapper.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/usecases/delete_logs_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/export_logs_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/load_logs_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/share_logs_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/logs_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _LogsRepository implements LogsRepository {
  @override
  Future<Result<List<LogEntry>, SettingsFailure>> read() async => Ok([
    LogEntryModel.fromRawLine('2026-01-01T00:00:00Z\tINFO\tmessage').toDomain(),
  ]);

  @override
  Future<Result<void, SettingsFailure>> delete() async => const Ok(null);

  @override
  Future<Result<void, SettingsFailure>> share(List<LogEntry> entries) async =>
      const Ok(null);

  @override
  Future<Result<bool, SettingsFailure>> export(List<LogEntry> entries) async =>
      const Ok(true);
}

void main() {
  test('loads once and exposes ready entries', () async {
    final repository = _LogsRepository();
    final cubit = LogsCubit(
      LoadLogsUsecase(repository),
      DeleteLogsUsecase(repository),
      ShareLogsUsecase(repository),
      ExportLogsUsecase(repository),
    );

    await cubit.load();
    expect(cubit.state.status.name, 'ready');
    expect(cubit.state.entries, hasLength(1));
    await cubit.load();
    await cubit.close();
  });
}
