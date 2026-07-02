import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/src/domain/secrets_error.dart';
import 'package:secrets/src/domain/value_objects/bip85_types.dart';

void main() {
  group('Bip85Path', () {
    test('parses hardened app number + index (with or without m/)', () {
      expect(Bip85Path("128169'/64'/3'").appNumber, 128169);
      expect(Bip85Path("128169'/64'/3'").index, 3);
      expect(Bip85Path("39'/0'/12'/0'").appNumber, 39);
    });

    test('an ABSOLUTE path strips the BIP85 root purpose (83696968\') so '
        'appNumber is the APPLICATION, not the root', () {
      // Previously `m/83696968'/39'/…` reported appNumber 83696968 (the root
      // purpose) — a footgun that mislabels/derives the wrong secret. It must
      // normalize to the app-rooted form.
      final p = Bip85Path("m/83696968'/39'/0'/12'/0'");
      expect(p.appNumber, 39);
      expect(p.index, 0);
      expect(p.path, "39'/0'/12'/0'");
      // Same for the no-`m/` absolute form.
      expect(Bip85Path("83696968'/128169'/64'/3'").appNumber, 128169);
    });

    test('rejects an empty / slash-less path at construction', () {
      expect(() => Bip85Path(''), throwsA(isA<InvalidBip85PathError>()));
      expect(() => Bip85Path('m/'), throwsA(isA<InvalidBip85PathError>()));
      expect(() => Bip85Path('noslash'), throwsA(isA<InvalidBip85PathError>()));
    });

    test('a non-numeric segment throws the typed error, not FormatException', () {
      // A malformed persisted path must surface as the package's typed error so
      // a caller can distinguish it — never a raw dart:core FormatException.
      final bad = Bip85Path("abc'/0'");
      expect(() => bad.appNumber, throwsA(isA<InvalidBip85PathError>()));
      final bad2 = Bip85Path("39'/xyz'");
      expect(() => bad2.index, throwsA(isA<InvalidBip85PathError>()));
    });
  });
}
