import 'package:labels/labels.dart';

class StoreSendTransactionLabelUsecase {
  final LabelsFacade _labels;

  StoreSendTransactionLabelUsecase(this._labels);

  Future<void> execute({
    required String transactionId,
    required String label,
    required String origin,
  }) async {
    await _labels.store(
      NewLabel.tx(transactionId: transactionId, label: label, origin: origin),
    );
  }
}
