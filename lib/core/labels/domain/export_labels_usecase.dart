import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/domain/label.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/file_system_repository.dart';
import 'package:bb_mobile/core/storage/tables/labels_table.dart';
import 'package:bb_mobile/core/utils/generic_extensions.dart';
import 'package:bip329_labels/bip329_labels.dart' as bip329;

class ExportLabelsUsecase {
  final LabelRepository _labelRepository;
  final _fileSystemRepository = FileSystemRepository();

  ExportLabelsUsecase({required LabelRepository labelRepository})
    : _labelRepository = labelRepository;

  Future<int> call() async {
    final labels = await _labelRepository.fetchAll();

    final bip329Labels =
        labels.map((label) {
          switch (label.type) {
            case LabelType.tx:
              return bip329.TxLabel(ref: label.ref, label: label.label);
            case LabelType.address:
              return bip329.AddressLabel(ref: label.ref, label: label.label);
            case LabelType.pubkey:
              return bip329.PubkeyLabel(ref: label.ref, label: label.label);
            case LabelType.input:
              return bip329.InputLabel(ref: label.ref, label: label.label);
            case LabelType.output:
              final spendable = label is OutputLabel ? label.spendable : null;
              return bip329.OutputLabel(
                ref: label.ref,
                label: label.label,
                spendable: spendable ?? false,
              );
            case LabelType.xpub:
              return bip329.XpubLabel(ref: label.ref, label: label.label);
          }
        }).toList();

    final filename =
        'bull_labels_${DateTime.now().toIso8601WithoutMilliseconds()}.jsonl';
    final jsonLines = bip329.Bip329Label.toJsonLines(bip329Labels);
    await _fileSystemRepository.saveFile(jsonLines, filename);

    return bip329Labels.length;
  }
}
