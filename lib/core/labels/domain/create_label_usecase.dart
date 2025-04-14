import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/data/labelable.dart';

class CreateLabelUsecase {
  final LabelRepository _labelRepository;

  CreateLabelUsecase({required LabelRepository labelRepository})
      : _labelRepository = labelRepository;

  Future<void> execute<T extends Labelable>({
    required String origin,
    required T entity,
    required String label,
    bool? spendable,
  }) async {
    try {
      // Get the wallet to calculate origin
      final wallet = await _wallet.getWallet(walletId);
      final origin = wallet.origin;

      final labelEntity = Label.create(
        type: type,
        ref: ref,
        label: label,
        origin: origin,
        label: label,
        entity: entity,
        spendable: spendable,
      );
    } catch (e) {
      throw CreateLabelException(e.toString());
    }
  }
}

class CreateLabelException implements Exception {
  final String message;

  CreateLabelException(this.message);
}
