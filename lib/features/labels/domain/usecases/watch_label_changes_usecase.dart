import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';

final class WatchLabelChangesUsecase {
  final LabelsRepositoryPort _repository;

  const WatchLabelChangesUsecase(this._repository);

  Stream<void> execute() => _repository.changes;
}
