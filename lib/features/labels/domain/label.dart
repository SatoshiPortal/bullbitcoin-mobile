import 'package:bb_mobile/features/labels/primitive/label_type.dart';

class Label {
  final LabelType type;
  final String label;
  final String reference;
  final String? origin;
  final bool? spendable;

  Label({
    required this.type,
    required this.label,
    required this.reference,
    this.origin,
    this.spendable,
  }) {
    switch (type) {
      case LabelType.transaction:
        if (reference.length != 64) throw Exception('Invalid tx reference');
      case LabelType.address:
      // deserialize using bdk and lwk
      case LabelType.publicKey:
      case LabelType.input:
      // check txid:int
      case LabelType.output:
      // check txid:int
      case LabelType.extendedPublicKey:
      // base58 decode size == 78
    }
  }
}
