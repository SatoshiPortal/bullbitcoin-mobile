import 'package:bb_mobile/features/labels/adapters/label_mapper.dart';
import 'package:bb_mobile/features/labels/application/application_label.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/domain/label_error.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class FetchAllLabelsUsecase {
  final LabelsRepositoryPort _labelRepository;

  FetchAllLabelsUsecase({required LabelsRepositoryPort labelRepository})
    : _labelRepository = labelRepository;

  Future<List<ApplicationLabel>> execute() async {
    try {
      final labels = await _labelRepository.fetchAll();
      return labels
          .map((label) => LabelMapper.labelEntityToApplicationLabel(label))
          .toList();
    } on LabelError {
      rethrow;
    } catch (e) {
      log.severe('$FetchAllLabelsUsecase: $e', trace: StackTrace.current);
      throw LabelError.unexpected('Failed to fetch all labels: $e');
    }
  }
}
