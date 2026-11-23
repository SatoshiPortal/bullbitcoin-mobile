import 'package:bull_logger/bull_logger.dart';
import 'package:labels/src/domain/application_label.dart';
import 'package:labels/src/domain/label_failure.dart';
import 'package:labels/src/domain/labels_repository_port.dart';
import 'package:labels/src/domain/new_label.dart';
import 'package:labels/src/domain/store_label_application.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class StoreLabelUsecase {
  final LabelsRepositoryPort _labelRepository;

  StoreLabelUsecase({required this._labelRepository});

  @useResult
  Future<Result<ApplicationLabel, LabelFailure>> execute(
    NewApplicationLabel label,
  ) async {
    try {
      final newLabel = NewLabel(
        type: label.type,
        label: label.label,
        reference: label.reference,
        origin: label.origin,
      );
      final storedLabel = await _labelRepository.store(newLabel);
      return Ok(ApplicationLabel.fromEntity(storedLabel));
    } catch (_) {
      const diagnostic = 'label_store_failed category=unexpected';
      log.severe(
        message: diagnostic,
        error: Exception(diagnostic),
        trace: StackTrace.current,
      );
      return const Err(LabelUnexpectedFailure(diagnostic));
    }
  }
}
