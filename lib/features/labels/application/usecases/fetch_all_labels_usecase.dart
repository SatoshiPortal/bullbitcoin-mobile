import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/adapters/label_mapper.dart';
import 'package:bb_mobile/features/labels/application/application_label.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:meta/meta.dart';

class FetchAllLabelsUsecase {
  final LabelsRepositoryPort _labelRepository;

  FetchAllLabelsUsecase({required this._labelRepository});

  @useResult
  Future<Result<List<ApplicationLabel>, LabelFailure>> execute() async {
    try {
      final labels = await _labelRepository.fetchAll();
      return Ok(
        labels
            .map((label) => LabelMapper.labelEntityToApplicationLabel(label))
            .toList(),
      );
    } catch (e, st) {
      // Keep the technical reason in the logs; the failure carries only the
      // logged-only reason and the UI maps it to a generic message.
      log.severe(message: 'Failed to fetch all labels', error: e, trace: st);
      return Err(LabelUnexpectedFailure('$e'));
    }
  }
}
