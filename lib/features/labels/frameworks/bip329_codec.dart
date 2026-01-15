import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/primitive/label_type.dart';
import 'package:bip329_labels/bip329_labels.dart' as bip329;

class Bip329LabelsCodec {
  String encode(List<LabelEntity> labels) {
    final bip329Labels = labels.map((label) {
      switch (label.type) {
        case LabelType.transaction:
          return bip329.TxLabel(ref: label.reference, label: label.label);
        case LabelType.address:
          return bip329.AddressLabel(ref: label.reference, label: label.label);
        case LabelType.publicKey:
          return bip329.PubkeyLabel(ref: label.reference, label: label.label);
        case LabelType.input:
          return bip329.InputLabel(ref: label.reference, label: label.label);
        case LabelType.output:
          return bip329.OutputLabel(
            ref: label.reference,
            label: label.label,
            spendable: label.spendable ?? true,
          );
        case LabelType.extendedPublicKey:
          return bip329.XpubLabel(ref: label.reference, label: label.label);
      }
    }).toList();

    final jsonLines = bip329.Bip329Label.toJsonLines(bip329Labels);
    return jsonLines;
  }

  List<LabelEntity> decode(String input) {
    var bip329Labels = <bip329.Bip329Label>[];
    try {
      bip329Labels = bip329.Bip329Label.fromJsonLines(input);
    } catch (e) {
      throw 'Failed to parse bip329 format';
    }
    if (bip329Labels.isEmpty) throw 'No labels found';

    final labels = <LabelEntity>[];
    for (final bip329Label in bip329Labels) {
      final label = _convertBip329ToLabel(bip329Label);
      labels.add(label);
    }
    return labels;
  }
}

LabelEntity _convertBip329ToLabel(bip329.Bip329Label bip329Label) {
  return switch (bip329Label) {
    bip329.TxLabel() => LabelEntity(
      type: LabelType.transaction,
      reference: bip329Label.ref,
      label: bip329Label.label,
      origin: bip329Label.origin,
    ),
    bip329.AddressLabel() => LabelEntity(
      type: LabelType.address,
      reference: bip329Label.ref,
      label: bip329Label.label,
      origin: bip329Label.origin,
    ),
    bip329.PubkeyLabel() => LabelEntity(
      type: LabelType.publicKey,
      reference: bip329Label.ref,
      label: bip329Label.label,
      origin: bip329Label.origin,
    ),
    bip329.InputLabel() => LabelEntity(
      type: LabelType.input,
      reference: bip329Label.ref,
      label: bip329Label.label,
      origin: bip329Label.origin,
    ),
    bip329.OutputLabel() => LabelEntity(
      type: LabelType.output,
      reference: bip329Label.ref,
      label: bip329Label.label,
      origin: bip329Label.origin,
      spendable: bip329Label.spendable,
    ),
    bip329.XpubLabel() => LabelEntity(
      type: LabelType.extendedPublicKey,
      reference: bip329Label.ref,
      label: bip329Label.label,
      origin: bip329Label.origin,
    ),
    _ => throw 'Unsupported label type: ${bip329Label.runtimeType}',
  };
}
