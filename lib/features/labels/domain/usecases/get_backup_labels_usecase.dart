import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:meta/meta.dart';

final class GetBackupLabelsUsecase {
  final LabelsRepositoryPort _repository;

  const GetBackupLabelsUsecase(this._repository);

  @useResult
  Future<Result<List<LabelEntity>, LabelFailure>> execute() async {
    try {
      return Ok(await _repository.fetchAllForBackup());
    } on Exception {
      return const Err(LabelUnexpectedFailure());
    }
  }
}
