import 'package:bb_mobile/features/pos/domain/pos_error.dart';
import 'package:bb_mobile/features/pos/domain/pos_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('POS label byte boundaries (server measures UTF-8 bytes)', () {
    test('accepts a 1..80-byte ASCII label', () {
      expect(isValidPosLabel('A'), isTrue);
      expect(isValidPosLabel('A' * 80), isTrue);
    });

    test('rejects empty and >80-byte labels', () {
      expect(isValidPosLabel(''), isFalse);
      expect(isValidPosLabel('A' * 81), isFalse);
    });

    test('measures bytes, not characters: a multibyte label fails below 80 '
        'visible characters', () {
      // '€' is 3 UTF-8 bytes. 27 of them = 81 bytes > 80, at only 27 chars.
      final label = '€' * 27;
      expect(label.length, 27);
      expect(posByteLength(label), 81);
      expect(isValidPosLabel(label), isFalse);
      // 26 of them = 78 bytes, still valid.
      expect(isValidPosLabel('€' * 26), isTrue);
    });
  });

  group('PosProvisionCommand.validate', () {
    test('valid command passes and reports no invalid field', () {
      const command = PosProvisionCommand(label: 'My Till', displayCurrency: 'CAD');
      expect(command.isValid, isTrue);
      expect(command.firstInvalidField(), isNull);
      command.validate();
    });

    test('an empty label is the first invalid field', () {
      const command = PosProvisionCommand(label: '', displayCurrency: 'CAD');
      expect(command.firstInvalidField(), PosField.label);
      expect(
        () => command.validate(),
        throwsA(
          isA<PosException>()
              .having((e) => e.kind, 'kind', PosErrorKind.invalidInput)
              .having((e) => e.code, 'code', 'label'),
        ),
      );
    });

    test('an empty display currency is invalid', () {
      const command = PosProvisionCommand(label: 'My Till', displayCurrency: '');
      expect(command.firstInvalidField(), PosField.displayCurrency);
      expect(
        () => command.validate(),
        throwsA(
          isA<PosException>().having((e) => e.code, 'code', 'displayCurrency'),
        ),
      );
    });

    test('has only label + currency fields: no image/socials/website rules', () {
      // The POS command carries exactly two fields (DELTA 2) - a compile-time
      // guarantee reinforced here: the field enum has no page-content members.
      expect(PosField.values, [PosField.label, PosField.displayCurrency]);
    });
  });
}
