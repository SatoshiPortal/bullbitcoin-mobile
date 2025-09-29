import 'package:bb_mobile/features/utxos/domain/label.dart';
import 'package:bb_mobile/features/utxos/domain/ports/labels_port.dart';

class LabelsGateway implements LabelsPort {
  // TODO: Add Labels feature usecases

  LabelsGateway();

  @override
  Future<void> addUtxoLabel(UtxoLabel label) async {
    // TODO: implement addUtxoLabel
    throw UnimplementedError();
  }

  @override
  Future<List<UtxoLabel>> getUtxoLabels({
    required String txId,
    required int index,
  }) async {
    return [];
  }

  @override
  Future<List<AddressLabel>> getAddressLabels(String address) async {
    return [];
  }

  @override
  Future<List<TransactionLabel>> getTransactionLabels(String txId) async {
    return [];
  }

  @override
  Future<void> removeUtxoLabel(UtxoLabel label) async {
    // TODO: implement removeUtxoLabel
    throw UnimplementedError();
  }
}
