import 'package:bull_logger/bull_logger.dart';
import 'package:labels/src/domain/application_label.dart';
import 'package:labels/src/domain/label_failure.dart';
import 'package:labels/src/domain/labels_repository_port.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class FetchAllLabelsUsecase {
  final LabelsRepositoryPort _labelRepository;

  FetchAllLabelsUsecase({required this._labelRepository});

  @useResult
  Future<Result<List<ApplicationLabel>, LabelFailure>> execute() async {
    try {
      final labels = await _labelRepository.fetchAll();
      return Ok(
        labels.map((label) => ApplicationLabel.fromEntity(label)).toList(),
      );
    } catch (e, st) {
      // Keep the technical reason in the logs; the failure carries only the
      // logged-only reason and the UI maps it to a generic message.
      log.severe(message: 'Failed to fetch all labels', error: e, trace: st);
      return Err(LabelUnexpectedFailure('$e'));
    }
  }
}
