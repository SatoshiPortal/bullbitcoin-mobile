import 'package:labels/labels.dart';

class StoreSellTransactionLabelUsecase {
  final LabelsFacade _labels;

  StoreSellTransactionLabelUsecase(this._labels);

  Future<void> execute({
    required String transactionId,
    required String? origin,
  }) async {
    await _labels.store(
      NewLabel.tx(
        transactionId: transactionId,
        label: LabelSystem.exchangeSell.label,
        origin: origin,
      ),
    );
  }
}
