import 'package:bb_mobile/core_deprecated/errors/bull_exception.dart';
import 'package:bb_mobile/core_deprecated/labels/data/label_repository.dart';
import 'package:bb_mobile/core_deprecated/labels/domain/label.dart';
import 'package:bb_mobile/core_deprecated/recoverbull/data/repository/file_system_repository.dart';
import 'package:bb_mobile/core_deprecated/utils/logger.dart';
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
    return switch (bip329Label) {
      bip329.TxLabel() => Label.tx(
        transactionId: bip329Label.ref,
        label: bip329Label.label,
        origin: bip329Label.origin,
      ),
      bip329.AddressLabel() => Label.addr(
        address: bip329Label.ref,
        label: bip329Label.label,
        origin: bip329Label.origin,
      ),
      bip329.PubkeyLabel() => Label.pubkey(
        pubkey: bip329Label.ref,
        label: bip329Label.label,
        origin: bip329Label.origin,
      ),
      bip329.InputLabel() => Label.input(
        txId: bip329Label.ref.split(':')[0],
        vin: int.parse(bip329Label.ref.split(':')[1]),
        label: bip329Label.label,
        origin: bip329Label.origin,
      ),
      bip329.OutputLabel() => Label.output(
        txId: bip329Label.ref.split(':')[0],
        vout: int.parse(bip329Label.ref.split(':')[1]),
        label: bip329Label.label,
        origin: bip329Label.origin,
        spendable: bip329Label.spendable,
      ),
      bip329.XpubLabel() => Label.xpub(
        xpub: bip329Label.ref,
        label: bip329Label.label,
        origin: bip329Label.origin,
      ),
      _ =>
        throw ImportLabelsError(
          'Unsupported label type: ${bip329Label.runtimeType}',
        ),
    };
  }
}

class ImportLabelsError extends BullException {
  ImportLabelsError(super.message);
}
