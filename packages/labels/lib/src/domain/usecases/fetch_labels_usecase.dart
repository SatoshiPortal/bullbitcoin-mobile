import 'package:bull_logger/bull_logger.dart';
import 'package:labels/src/domain/application_label.dart';
import 'package:labels/src/domain/label_failure.dart';
import 'package:labels/src/domain/labels_repository_port.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class FetchLabelsUsecase {
  final LabelsRepositoryPort _labelRepository;

  FetchLabelsUsecase(this._labelRepository);

  @useResult
  Future<Result<List<ApplicationLabel>, LabelFailure>> execute({
    String? reference,
  }) async {
    try {
      final labels = reference == null
          ? await _labelRepository.fetchAll()
          : await _labelRepository.fetchByReference(reference);
      return Ok(
        labels.map((label) => ApplicationLabel.fromEntity(label)).toList(),
      );
    } catch (e, st) {
      // Keep transaction IDs, addresses and xpubs out of the log message.
      log.severe(message: 'Failed to fetch labels', error: e, trace: st);
      return Err(LabelUnexpectedFailure('$e'));
    }
  }
}
