import 'package:bb_mobile/features/labels/application/labels_converter_port_registry.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/application/wallet_freeze_port.dart';
import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class ExportLabelsUsecase {
  final LabelsRepositoryPort _labelRepository;
  final LabelsConverterPortRegistry _converterRegistry;
  final WalletFreezePort _walletFreeze;

  ExportLabelsUsecase({
    required this._labelRepository,
    required this._converterRegistry,
    required this._walletFreeze,
  });

  /// The serialized labels, ready to write to a file.
  ///
  /// The boundary for the label store and the converter, so the cubit no
  /// longer catches on its behalf.
  @useResult
  Future<Result<String, LabelFailure>> call(LabelFormat format) async {
    try {
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
      return Ok(_getExportString(formattedLabels));
    } on Object catch (e, st) {
      // warning, not severe: the reason can quote the labels being exported.
      log.warning('Failed to export labels', error: e, trace: st);
      return const Err(LabelsExportFailure());
    }
  }

  String _getExportString(FormattedLabels formattedLabels) {
    switch (formattedLabels) {
      case FormattedLabelsBIP329():
        return formattedLabels.jsonl;
    }
  }
}
