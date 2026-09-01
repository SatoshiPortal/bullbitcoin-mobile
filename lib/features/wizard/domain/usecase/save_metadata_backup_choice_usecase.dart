import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';
import 'package:bb_mobile/features/wizard/domain/wizard_failure.dart';
import 'package:primitives/primitives.dart';

final class SaveMetadataBackupChoiceUsecase {
  final WizardRepository _repository;

  const SaveMetadataBackupChoiceUsecase({required this._repository});

  Future<Result<void, WizardFailure>> execute(bool enabled) =>
      _repository.saveMetadataBackupChoice(enabled);
}
