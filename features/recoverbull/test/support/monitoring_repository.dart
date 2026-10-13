import 'package:bull_recoverbull/src/data/recoverbull_attempt_monitoring_store.dart';
import 'package:bull_recoverbull/src/data/recoverbull_attempt_monitoring_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'log_sink.dart';

RecoverBullAttemptMonitoringRepository monitoringRepository(
  RecoverBullAttemptMonitoringStore store,
) =>
    RecoverBullAttemptMonitoringRepositoryImpl(store, log: const TestLogSink());

extension CheckedResult<T, F extends Failure> on Future<Result<T, F>> {
  Future<T> requireOk() async {
    final result = await this;
    expect(result, isA<Ok<T, F>>());
    return (result as Ok<T, F>).value;
  }
}
