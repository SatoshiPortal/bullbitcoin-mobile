import 'package:bb_mobile/features/labels/data/label_repository.dart';
import 'package:bb_mobile/features/labels/domain/label.dart';
import 'package:bb_mobile/features/labels/domain/label_error.dart';

class LabelAddressUsecase {
  final LabelRepository _labelRepository;

  LabelAddressUsecase({required LabelRepository labelRepository})
    : _labelRepository = labelRepository;

  Future<void> execute({
    required String address,
    required String label,
    required String? origin,
  }) async {
    try {
      final addressLabel = Label.addr(
        address: address,
        label: label,
        origin: origin,
      );
      await _labelRepository.store(addressLabel);
    } on LabelError {
      rethrow;
    } catch (e) {
      throw LabelError.unexpected(
        'Failed to create label for address $address: $e',
      );
    }
  }
}
