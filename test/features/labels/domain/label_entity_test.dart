import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validTxid =
      '5f1fabc488e1df397e90114374277f2edfa7613fec96769f22d7aa828142709c';

  group('LabelEntity reference validation', () {
    test('transaction: accepts a bare 64-hex-char txid', () {
      expect(
        () => LabelEntity(
          id: 1,
          type: LabelType.transaction,
          label: 'l',
          reference: validTxid,
        ),
        returnsNormally,
      );
    });

    test('transaction: rejects a non-64-char reference', () {
      expect(
        () => LabelEntity(
          id: 1,
          type: LabelType.transaction,
          label: 'l',
          reference: 'not-a-txid',
        ),
        throwsA(isA<LabelValidationException>()),
      );
    });

    // Regression: `_validateTxid` used to validate the full `reference`
    // field (`txid:vout`) instead of the txid slice it was passed,
    // rejecting every well-formed input/output/publicKey label
    // unconditionally — e.g. the payjoin repository's "prefer re-exposing
    // an already-exposed UTXO" anti-probing mitigation, which silently
    // never persisted a label (caught, warning-logged, swallowed).
    for (final type in [
      LabelType.output,
      LabelType.input,
      LabelType.publicKey,
    ]) {
      test('$type: accepts a valid `txid:vout` reference', () {
        expect(
          () => LabelEntity(
            id: 1,
            type: type,
            label: 'l',
            reference: '$validTxid:0',
          ),
          returnsNormally,
        );
      });

      test('$type: rejects a malformed txid slice', () {
        expect(
          () => LabelEntity(
            id: 1,
            type: type,
            label: 'l',
            reference: 'not-a-txid:0',
          ),
          throwsA(isA<LabelValidationException>()),
        );
      });

      test('$type: rejects a negative vout', () {
        expect(
          () => LabelEntity(
            id: 1,
            type: type,
            label: 'l',
            reference: '$validTxid:-1',
          ),
          throwsA(isA<LabelValidationException>()),
        );
      });
    }
  });
}
