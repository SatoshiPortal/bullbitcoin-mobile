import 'package:bull_logger/bull_logger.dart';
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
  Future<Result<List<ApplicationLabel>, LabelFailure>> execute({
    bool strict = false,
  }) async {
    try {
      final labels = await _labelRepository.fetchAll(strict: strict);
      return Ok(
        labels
            .map((label) => LabelMapper.labelEntityToApplicationLabel(label))
            .toList(),
      );
    } catch (e, st) {
      // Database errors can contain the failed query and private label data.
      log.severe(
        message: 'Failed to fetch all labels',
        error: e.runtimeType,
        trace: st,
      );
      return const Err(LabelUnexpectedFailure('Failed to fetch all labels'));
    }
  }
}
