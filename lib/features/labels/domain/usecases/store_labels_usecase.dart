import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/application/store_label_dto.dart';
import 'package:bb_mobile/features/labels/domain/label_error.dart';

class StoreLabelsUsecase {
  final LabelsRepositoryPort _labelRepository;

  StoreLabelsUsecase({required LabelsRepositoryPort labelRepository})
    : _labelRepository = labelRepository;

  Future<void> execute(List<StoreLabelDto> labelDtos) async {
    try {
      final labels = labelDtos.map((dto) => dto.toDomain()).toList();
      await _labelRepository.store(labels);
    } on LabelError {
      rethrow;
    } catch (e) {
      throw LabelError.unexpected('Failed to batch labels: $e');
    }
  }
}
