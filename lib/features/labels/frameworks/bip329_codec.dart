import 'package:bb_mobile/features/labels/domain/label.dart';
import 'package:bb_mobile/features/labels/primitive/label_type.dart';
import 'package:bip329_labels/bip329_labels.dart' as bip329;

class Bip329LabelsCodec {
  String encode(List<Label> labels) {
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

  List<Label> decode(String input) {
    var bip329Labels = <bip329.Bip329Label>[];
    try {
      bip329Labels = bip329.Bip329Label.fromJsonLines(input);
    } catch (e) {
      throw 'Failed to parse bip329 format';
    }
    if (bip329Labels.isEmpty) throw 'No labels found';

    final labels = <Label>[];
    for (final bip329Label in bip329Labels) {
      final label = _convertBip329ToLabel(bip329Label);
      labels.add(label);
    }
    return labels;
  }
}

Label _convertBip329ToLabel(bip329.Bip329Label bip329Label) {
  return switch (bip329Label) {
    bip329.TxLabel() => Label(
      type: LabelType.transaction,
      reference: bip329Label.ref,
      label: bip329Label.label,
      origin: bip329Label.origin,
    ),
    bip329.AddressLabel() => Label(
      type: LabelType.address,
      reference: bip329Label.ref,
      label: bip329Label.label,
      origin: bip329Label.origin,
    ),
    bip329.PubkeyLabel() => Label(
      type: LabelType.publicKey,
      reference: bip329Label.ref,
      label: bip329Label.label,
      origin: bip329Label.origin,
    ),
    bip329.InputLabel() => Label(
      type: LabelType.input,
      reference: bip329Label.ref,
      label: bip329Label.label,
      origin: bip329Label.origin,
    ),
    bip329.OutputLabel() => Label(
      type: LabelType.output,
      reference: bip329Label.ref,
      label: bip329Label.label,
      origin: bip329Label.origin,
      spendable: bip329Label.spendable,
    ),
    bip329.XpubLabel() => Label(
      type: LabelType.extendedPublicKey,
      reference: bip329Label.ref,
      label: bip329Label.label,
      origin: bip329Label.origin,
    ),
    _ => throw 'Unsupported label type: ${bip329Label.runtimeType}',
  };
}
