import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../logs_failure.dart';
import '../repositories/logs_repository.dart';

final class ExportAllLogsUsecase {
  final LogsRepository _repository;

  const ExportAllLogsUsecase(this._repository);

  @useResult
  Future<Result<bool, LogsFailure>> execute() async {
    final result = await _repository.read();
    return switch (result) {
      Ok(:final value) => _repository.export(value),
      Err(:final failure) => Err(failure),
    };
  }
}
