import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/domain/label.dart';
import 'package:bb_mobile/core/labels/domain/label_error.dart';

class LabelTransactionUsecase {
  final LabelRepository _labelRepository;

  LabelTransactionUsecase({required LabelRepository labelRepository})
    : _labelRepository = labelRepository;

  Future<Label> execute({
    required String txid,
    required String? origin,
    required String label,
  }) async {
    try {
      final transactionLabel = Label.tx(
        transactionId: txid,
        label: label,
        origin: origin,
      );
      await _labelRepository.store(transactionLabel);
      return transactionLabel;
    } on LabelError {
      rethrow;
    } catch (e) {
      throw LabelError.unexpected(
        'Failed to create label for transaction $txid: $e',
      );
    }
  }
}
