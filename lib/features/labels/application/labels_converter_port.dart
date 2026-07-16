import 'package:bb_mobile/features/labels/domain/decoded_labels.dart';
import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';
import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';
import 'package:bb_mobile/features/labels/domain/new_label.dart';
import 'package:bb_mobile/features/labels/bip329_label_record.dart';

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

  /// Serializes only persisted annotations for encrypted metadata backup.
  List<Bip329LabelRecord> convertToMetadataRecords(List<LabelEntity> labels);

  /// Parses annotation-only encrypted metadata records.
  List<NewLabel> convertFromMetadataRecords(List<Bip329LabelRecord> records);
}
