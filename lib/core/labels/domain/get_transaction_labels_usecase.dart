import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/domain/label.dart';

class GetTransactionLabelsUsecase {
  final LabelRepository _labelRepository;

  GetTransactionLabelsUsecase({required LabelRepository labelRepository})
    : _labelRepository = labelRepository;

  Future<List<TxLabel>> execute(String txId) async {
    return _labelRepository.fetchTransactionLabels(txId);
  }
}
