import 'package:bb_mobile/features/labels/domain/decoded_labels.dart';
import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';
import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';

abstract class LabelsConverterPort {
  /// Serializes [labels] plus the [frozen] outpoints (projected onto BIP329
  /// `spendable`). `walletId` in [frozen] is the wallet origin.
  FormattedLabels convertTo({
    required LabelFormat format,
    required List<LabelEntity> labels,
    List<({String walletId, String txId, int vout})> frozen,
  });

  /// Parses a file into annotations plus freeze state (two channels).
  DecodedLabels convertFrom(FormattedLabels formattedLabels);
}
