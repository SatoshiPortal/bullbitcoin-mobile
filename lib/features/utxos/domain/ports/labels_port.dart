import 'package:bb_mobile/core/labels/domain/label.dart';

abstract class LabelsPort {
  Future<void> addUtxoLabel(OutputLabel label);
  Future<List<OutputLabel>> getUtxoLabels({
    required String txId,
    required int index,
  });
  Future<List<AddressLabel>> getAddressLabels(String address);
  Future<List<TxLabel>> getTransactionLabels(String txId);
  Future<void> removeUtxoLabel(OutputLabel label);
}
