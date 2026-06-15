import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/domain/label_error.dart';

class TrashLabelUsecase {
  final LabelsRepositoryPort _labelRepository;

  TrashLabelUsecase({required this._labelRepository});

  Future<void> execute(int id) async {
    try {
      await _labelRepository.trash(id);
    } on LabelError {
      rethrow;
    } catch (e, st) {
      // Keep the technical reason in the logs; the UI maps the unexpected
      // variant to a generic message and never shows [e].
      log.severe(message: 'Failed to trash label $id', error: e, trace: st);
      throw UnexpectedLabelError('Failed to trash label $id: $e');
    }
  }
}
