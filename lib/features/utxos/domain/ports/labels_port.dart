import 'package:bb_mobile/features/utxos/domain/label.dart';

abstract class LabelsPort {
  Future<void> addUtxoLabel(UtxoLabel label);
  Future<List<UtxoLabel>> getUtxoLabels({
    required String txId,
    required int index,
  });
  Future<List<AddressLabel>> getAddressLabels(String address);
  Future<List<TransactionLabel>> getTransactionLabels(String txId);
  Future<void> removeUtxoLabel(UtxoLabel label);
}
