import 'package:bb_mobile/core/labels/domain/get_address_labels_usecase.dart';
import 'package:bb_mobile/core/labels/domain/get_output_labels_usecase.dart';
import 'package:bb_mobile/core/labels/domain/get_transaction_labels_usecase.dart';
import 'package:bb_mobile/core/labels/domain/label.dart';
import 'package:bb_mobile/core/labels/domain/ports/labels_port.dart';

class LabelsFacade implements LabelsPort {
  final GetAddresLabelsUsecase _getAddressLabelsUsecase;
  final GetTransactionLabelsUsecase _getTransactionLabelsUsecase;
  final GetOutputLabelsUsecase _getOutputLabelsUsecase;

  LabelsFacade({
    required GetAddresLabelsUsecase getAddressLabelsUsecase,
    required GetTransactionLabelsUsecase getTransactionLabelsUsecase,
    required GetOutputLabelsUsecase getOutputLabelsUsecase,
  }) : _getAddressLabelsUsecase = getAddressLabelsUsecase,
       _getTransactionLabelsUsecase = getTransactionLabelsUsecase,
       _getOutputLabelsUsecase = getOutputLabelsUsecase;

  @override
  Future<void> addUtxoLabel(OutputLabel label) {
    // TODO: implement addUtxoLabel
    throw UnimplementedError();
  }

  @override
  Future<List<AddressLabel>> getAddressLabels(String address) {
    return _getAddressLabelsUsecase.execute(address);
  }

  @override
  Future<List<TxLabel>> getTransactionLabels(String txId) {
    return _getTransactionLabelsUsecase.execute(txId);
  }

  @override
  Future<List<OutputLabel>> getUtxoLabels({
    required String txId,
    required int index,
  }) {
    return _getOutputLabelsUsecase.execute(txId, index);
  }

  @override
  Future<void> removeUtxoLabel(OutputLabel label) {
    // TODO: implement removeUtxoLabel
    throw UnimplementedError();
  }
}
