import 'dart:convert';

import 'package:bb_mobile/_model/label.dart';
import 'package:test/test.dart';

void main() {
  test('Test Label Model', () async {
    const example =
        "{ 'type': 'tx', 'ref': 'f546156d9044844e02b181026a1a407abfca62e7ea1159f87bbeaa77b4286c74', 'label': 'Account #1 Transaction,Exchange,BullWallet', 'origin': 'wpkh([d34db33f/84'/0'/1']) }";
    final label = Label.fromJson((jsonDecode(example)) as Map<String, dynamic>);
    print(label);
    assert(label.type == LabelType.tx); // check string to enum conversion
    assert(label.labelList().length == 3);
  });
}
