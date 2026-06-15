import 'package:bb_mobile/features/labels/adapters/label_mapper.dart';
import 'package:bb_mobile/features/labels/application/application_label.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/domain/label_error.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class FetchAllLabelsUsecase {
  final LabelsRepositoryPort _labelRepository;

  FetchAllLabelsUsecase({required this._labelRepository});

  Future<List<ApplicationLabel>> execute() async {
    try {
      final labels = await _labelRepository.fetchAll();
      return labels
          .map((label) => LabelMapper.labelEntityToApplicationLabel(label))
          .toList();
    } on LabelError {
      rethrow;
    } catch (e, st) {
      // Keep the technical reason in the logs; the UI maps the unexpected
      // variant to a generic message and never shows [e].
      log.severe(message: 'Failed to fetch all labels', error: e, trace: st);
      throw UnexpectedLabelError('Failed to fetch all labels: $e');
    }
  }
}
