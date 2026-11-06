import 'package:bb_mobile/features/labels/domain/primitive/label_system.dart';
import 'package:bb_mobile/features/labels/new_label.dart';
import 'package:bull_payjoin/bull_payjoin.dart';

final class AppPayjoinLabelsAdapter implements PayjoinLabelsPort {
  final Future<void> Function(NewLabel) _store;

  const AppPayjoinLabelsAdapter(this._store);

  @override
  Future<void> labelTransaction({
    required String walletId,
    required String transactionId,
  }) async {
    await _store(
      NewLabel.tx(
        transactionId: transactionId,
        label: LabelSystem.payjoin.label,
        origin: walletId,
      ),
    );
  }
}
