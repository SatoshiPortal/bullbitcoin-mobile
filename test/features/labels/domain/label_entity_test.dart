import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LabelEntity reference validation', () {
    final validTxid = 'a' * 64;

    test('accepts a well-formed transaction reference', () {
      expect(
        () => LabelEntity(
          id: 1,
          type: LabelType.transaction,
          label: 'test',
          reference: validTxid,
        ),
        returnsNormally,
      );
    });

    test('accepts a well-formed input reference (txid:vout) — regression for '
        'the bug where the full reference was validated instead of the txid '
        'slice, rejecting every well-formed input/output/publicKey label', () {
      expect(
        () => LabelEntity(
          id: 1,
          type: LabelType.input,
          label: 'test',
          reference: '$validTxid:0',
        ),
        returnsNormally,
      );
    });

    test('accepts a well-formed output reference (txid:vout)', () {
      expect(
        () => LabelEntity(
          id: 1,
          type: LabelType.output,
          label: 'test',
          reference: '$validTxid:12',
        ),
        returnsNormally,
      );
    });

    test('accepts a well-formed publicKey reference (compressed pubkey) — '
        'per BIP-329 a pubkey ref is a public key, not txid:vout', () {
      expect(
        () => LabelEntity(
          id: 1,
          type: LabelType.publicKey,
          label: 'test',
          reference:
              '0250863ad64a87ae8a2fe83c1af1a8403cb53f53e486d8511dad8a04887e5b2352',
        ),
        returnsNormally,
      );
    });

    test('accepts a well-formed publicKey reference (x-only pubkey)', () {
      expect(
        () => LabelEntity(
          id: 1,
          type: LabelType.publicKey,
          label: 'test',
          reference:
              '50863ad64a87ae8a2fe83c1af1a8403cb53f53e486d8511dad8a04887e5b2352',
        ),
        returnsNormally,
      );
    });

    test('rejects a publicKey reference that is not hex or key-length', () {
      expect(
        () => LabelEntity(
          id: 1,
          type: LabelType.publicKey,
          label: 'test',
          reference: '$validTxid:1',
        ),
        throwsA(isA<LabelValidationException>()),
      );
    });

    test('rejects an input reference with no txid:vout separator with a '
        'LabelValidationException, not a RangeError', () {
      expect(
        () => LabelEntity(
          id: 1,
          type: LabelType.input,
          label: 'test',
          reference: validTxid,
        ),
        throwsA(isA<LabelValidationException>()),
      );
    });

    test('rejects an input reference with a non-hex txid slice', () {
      expect(
        () => LabelEntity(
          id: 1,
          type: LabelType.input,
          label: 'test',
          reference: '${'z' * 64}:0',
        ),
        throwsA(isA<LabelValidationException>()),
      );
    });

    test('rejects an input reference with a negative vout', () {
      expect(
        () => LabelEntity(
          id: 1,
          type: LabelType.input,
          label: 'test',
          reference: '$validTxid:-1',
        ),
        throwsA(isA<LabelValidationException>()),
      );
    });

    test('rejects a transaction reference that is not 64 hex characters', () {
      expect(
        () => LabelEntity(
          id: 1,
          type: LabelType.transaction,
          label: 'test',
          reference: 'tooshort',
        ),
        throwsA(isA<LabelValidationException>()),
      );
    });
  });
}
