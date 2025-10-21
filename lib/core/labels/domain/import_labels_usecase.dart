import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/domain/label.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/file_system_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bip329_labels/bip329_labels.dart' as bip329;

class ImportLabelsUsecase {
  final LabelRepository _labelRepository;
  final _fileSystemRepository = FileSystemRepository();

  ImportLabelsUsecase({required LabelRepository labelRepository})
    : _labelRepository = labelRepository;

  Future<int> call() async {
    final fileContent = await _fileSystemRepository.pickFile(
      // extensions: ['jsonl'], // FilePicker doesn't seems to support jsonl –> https://github.com/miguelpruivo/flutter_file_picker/issues/1903
    );

    var bip329Labels = <bip329.Bip329Label>[];
    try {
      bip329Labels = bip329.Bip329Label.fromJsonLines(fileContent);
    } catch (e) {
      throw ImportLabelsError('Failed to parse bip329 format');
    }

    if (bip329Labels.isEmpty) throw ImportLabelsError('No labels found');

    try {
      final labels = <Label>[];
      for (final bip329Label in bip329Labels) {
        final label = _convertBip329ToLabel(bip329Label);
        labels.add(label);
      }
      await _labelRepository.batch(labels);

      return labels.length;
    } catch (e) {
      log.severe('Failed to import labels: $e');
      throw ImportLabelsError('Failed to import labels: $e');
    }
  }

  Label _convertBip329ToLabel(bip329.Bip329Label bip329Label) {
    switch (bip329Label) {
      case bip329.TxLabel():
        return Label.tx(
          transactionId: bip329Label.ref,
          label: bip329Label.label,
          walletId: bip329Label.origin ?? '',
        );
      case bip329.AddressLabel():
        return Label.addr(
          address: bip329Label.ref,
          label: bip329Label.label,
          walletId: bip329Label.origin ?? '',
        );
      case bip329.PubkeyLabel():
        return Label.pubkey(
          pubkey: bip329Label.ref,
          label: bip329Label.label,
          walletId: bip329Label.origin ?? '',
        );
      case bip329.InputLabel():
        final parts = bip329Label.ref.split(':');
        return Label.input(
          txId: parts[0],
          vin: int.parse(parts[1]),
          label: bip329Label.label,
          walletId: bip329Label.origin ?? '',
        );
      case bip329.OutputLabel():
        final parts = bip329Label.ref.split(':');
        return Label.output(
          txId: parts[0],
          vout: int.parse(parts[1]),
          label: bip329Label.label,
          walletId: bip329Label.origin ?? '',
          spendable: bip329Label.spendable,
        );
      case bip329.XpubLabel():
        return Label.xpub(
          xpub: bip329Label.ref,
          label: bip329Label.label,
          walletId: bip329Label.origin ?? '',
        );
      default:
        throw ImportLabelsError(
          'Unsupported label type: ${bip329Label.runtimeType}',
        );
    }
  }
}

class ImportLabelsError extends BullException {
  ImportLabelsError(super.message);
}
