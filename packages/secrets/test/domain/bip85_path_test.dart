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

    test('a non-numeric segment throws the typed error AT CONSTRUCTION, not '
        'FormatException', () {
      // A malformed persisted path must surface as the package's typed error so
      // a caller can distinguish it — never a raw dart:core FormatException —
      // and it must fail EAGERLY at construction, not later in a getter.
      expect(() => Bip85Path("abc'/0'"),
          throwsA(isA<InvalidBip85PathError>()));
      expect(() => Bip85Path("39'/xyz'"),
          throwsA(isA<InvalidBip85PathError>()));
    });

    test('a MALFORMED segment (stray apostrophe / negative) is rejected at '
        'construction, not silently coerced', () {
      // A blanket apostrophe-strip + int.tryParse would accept "'12'" → 12 and
      // "-1'" → -1, constructing a DIFFERENT path identity (breaking ==/dedup and
      // mislabeling the secret). The strict per-segment shape rejects both — and
      // it does so when the value object is built (precondition model).
      expect(() => Bip85Path("'12'/0'"),
          throwsA(isA<InvalidBip85PathError>()));
      expect(() => Bip85Path("39'/-1'"),
          throwsA(isA<InvalidBip85PathError>()));
    });

    test('a segment at or beyond 2^31 (not hardened-representable) is rejected '
        'at construction', () {
      // Every BIP85 element is hardened, so a value >= 2^31 cannot be a valid
      // segment — it would overflow / collide with a different hardened index.
      expect(() => Bip85Path("39'/2147483648'"),
          throwsA(isA<InvalidBip85PathError>()));
    });
  });
}
