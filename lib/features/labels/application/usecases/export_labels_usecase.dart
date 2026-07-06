import 'package:bb_mobile/features/labels/application/labels_converter_port_registry.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/application/wallet_freeze_port.dart';
import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';

class ExportLabelsUsecase {
  final LabelsRepositoryPort _labelRepository;
  final LabelsConverterPortRegistry _converterRegistry;
  final WalletFreezePort _walletFreeze;

  ExportLabelsUsecase({
    required this._labelRepository,
    required this._converterRegistry,
    required this._walletFreeze,
  });

  Future<String> call(LabelFormat format) async {
    final labels = await _labelRepository.fetchAll();
    // Freeze state is projected onto BIP329 `spendable` at the boundary — it is
    // not stored as a label. The global frozen set is wallet-attributed via the
    // origin each row carries.
    final frozen = await _walletFreeze.getAllFrozen();
    final converter = _converterRegistry.getConverter(format);
    final formattedLabels = converter.convertTo(
      format: format,
      labels: labels,
      frozen: frozen,
    );
    return _getExportString(formattedLabels);
  }

  String _getExportString(FormattedLabels formattedLabels) {
    switch (formattedLabels) {
      case FormattedLabelsBIP329():
        return formattedLabels.jsonl;
    }
  }
}
