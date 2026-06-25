import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/labels/application/labels_converter_port.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/application/wallet_freeze_port.dart';
import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';

class ImportLabelsUsecase {
  final LabelsRepositoryPort _labelRepository;
  final LabelsConverterPort _labelConverter;
  final WalletFreezePort _walletFreeze;

  ImportLabelsUsecase({
    required this._labelRepository,
    required this._labelConverter,
    required this._walletFreeze,
  });

  Future<int> call(FormattedLabels labels) async {
    try {
      final decoded = _labelConverter.convertFrom(labels);
      for (final newLabel in decoded.labels) {
        await _labelRepository.store(newLabel);
      }
      // Freeze state imported as a separate channel (never a label row). An
      // `spendable: false` adopted here becomes a durable freeze the user owns;
      // matched by outpoint, so it applies to whichever wallet holds the coin.
      await _walletFreeze.freeze(decoded.frozen);
      return decoded.labels.length;
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      throw ImportLabelsError('Failed to import labels: $e');
    }
  }
}

class ImportLabelsError extends BullException {
  ImportLabelsError(super.message);
}
