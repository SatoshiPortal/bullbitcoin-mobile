import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';
import 'package:bb_mobile/features/labels/label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // `Label` is pure data read back from storage. Without value equality every
  // read produced objects that compared unequal, which propagated into the
  // `==` of every entity holding a `List<Label>` — most visibly `WalletUtxo`,
  // where it made a labelled coin compare unequal to its own re-read.
  group('Label equality', () {
    test('two reads of the same row compare equal', () {
      final a = Label.addr(id: 1, address: 'bc1-addr', label: 'Payjoin');
      final b = Label.addr(id: 1, address: 'bc1-addr', label: 'Payjoin');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect([a], equals([b]));
      expect({a}, equals({b}));
    });

    test('differs on any field', () {
      final base = Label.addr(id: 1, address: 'bc1-addr', label: 'Payjoin');

      expect(
        base,
        isNot(Label.addr(id: 2, address: 'bc1-addr', label: 'Payjoin')),
      );
      expect(
        base,
        isNot(Label.addr(id: 1, address: 'bc1-other', label: 'Payjoin')),
      );
      expect(
        base,
        isNot(Label.addr(id: 1, address: 'bc1-addr', label: 'Coinjoin')),
      );
      expect(
        base,
        isNot(
          Label.addr(
            id: 1,
            address: 'bc1-addr',
            label: 'Payjoin',
            origin: 'bip329',
          ),
        ),
      );
    });

    test(
      'a tx label never equals an address label with the same reference',
      () {
        final tx = Label.tx(id: 1, transactionId: 'ref', label: 'Payjoin');
        final addr = Label.addr(id: 1, address: 'ref', label: 'Payjoin');

        expect(tx.type, LabelType.transaction);
        expect(addr.type, LabelType.address);
        expect(tx, isNot(addr));
      },
    );
  });
}
