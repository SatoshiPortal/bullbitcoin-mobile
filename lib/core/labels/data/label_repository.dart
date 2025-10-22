import 'package:bb_mobile/core/labels/data/label_datasource.dart';
import 'package:bb_mobile/core/labels/data/label_model.dart';
import 'package:bb_mobile/core/labels/domain/label.dart';

class LabelRepository {
  final LabelDatasource _labelDatasource;

  LabelRepository({required LabelDatasource labelDatasource})
    : _labelDatasource = labelDatasource;

  Future<void> store(Label label) async {
    final model = LabelModel.fromEntity(label);

    await _labelDatasource.store(model);
  }

  Future<List<Label>> fetchByLabel(String label) async {
    final labelModels = await _labelDatasource.fetchByLabel(label: label);
    return labelModels.map((model) => model.toEntity()).toList();
  }

  Future<List<AddressLabel>> fetchAddressLabels(String address) async {
    final labelModels = await _labelDatasource.fetchByRef(address);
    return labelModels
        .map((model) => model.toEntity() as AddressLabel)
        .toList();
  }

  Future<List<TxLabel>> fetchTransactionLabels(String txId) async {
    final labelModels = await _labelDatasource.fetchByRef(txId);
    return labelModels.map((model) => model.toEntity() as TxLabel).toList();
  }

  Future<List<OutputLabel>> fetchOutputLabels({
    required String txId,
    required int index,
  }) async {
    final labelModels = await _labelDatasource.fetchByRef('$txId:$index');
    return labelModels.map((model) => model.toEntity() as OutputLabel).toList();
  }

  Future<void> trashByLabel(String label) async {
    await _labelDatasource.trashByLabel(label: label);
  }

  Future<void> trashLabel(Label label) async {
    final model = LabelModel.fromEntity(label);
    await _labelDatasource.trashLabel(model);
  }

  Future<List<Label>> fetchAll() async {
    final labelModels = await _labelDatasource.fetchAll();
    return labelModels.map((model) => model.toEntity()).toList();
  }

  Future<void> trashAll() async {
    await _labelDatasource.trashAll();
  }
}
