import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/domain/label.dart';

class GetOutputLabelsUsecase {
  final LabelRepository _labelRepository;

  GetOutputLabelsUsecase({required LabelRepository labelRepository})
    : _labelRepository = labelRepository;

  Future<List<OutputLabel>> execute(String txId, int index) async {
    return _labelRepository.fetchOutputLabels(txId: txId, index: index);
  }
}
