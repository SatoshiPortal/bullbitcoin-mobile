import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/adapters/label_mapper.dart';
import 'package:bb_mobile/features/labels/application/application_label.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/application/store_label_application.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:bb_mobile/features/labels/domain/new_label.dart';
import 'package:meta/meta.dart';

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
      return Ok(LabelMapper.labelEntityToApplicationLabel(storedLabel));
    } catch (e, st) {
      // Keep the technical reason in the logs; the failure carries only the
      // logged-only reason and the UI maps it to a generic message.
      log.severe(message: 'Failed to store label', error: e, trace: st);
      return Err(LabelUnexpectedFailure('$e'));
    }
  }
}
