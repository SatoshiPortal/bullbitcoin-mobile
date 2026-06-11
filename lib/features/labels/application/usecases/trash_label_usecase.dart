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
    } catch (e) {
      throw LabelError.unexpected('Failed to trash label $id: $e');
    }
  }
}
