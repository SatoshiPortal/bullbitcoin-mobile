import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../logs_failure.dart';
import '../repositories/logs_repository.dart';

final class ShareAllLogsUsecase {
  final LogsRepository _repository;

  const ShareAllLogsUsecase(this._repository);

  @useResult
  Future<Result<void, LogsFailure>> execute() async {
    final result = await _repository.read();
    return switch (result) {
      Ok(:final value) => _repository.share(value),
      Err(:final failure) => Err(failure),
    };
  }
}
