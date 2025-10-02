import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/domain/label.dart';

class GetAddressLabelsUsecase {
  final LabelRepository _labelRepository;

  GetAddressLabelsUsecase({required LabelRepository labelRepository})
    : _labelRepository = labelRepository;

  Future<List<AddressLabel>> execute(String address) {
    return _labelRepository.fetchAddressLabels(address);
  }
}
