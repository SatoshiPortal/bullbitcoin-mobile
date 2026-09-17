import 'dart:typed_data';

import 'package:bs58check/bs58check.dart' as base58;
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  // A structurally valid extended key: version bytes plus a 74-byte
  // payload, base58check-encoded. Synthetic on purpose — a memorised
  // real-world vector that turned out wrong would fail a correct
  // implementation, or worse, get "fixed" to match.
  final payload = Uint8List.fromList(List<int>.generate(74, (i) => i));
  final xpub = base58.encode(
    Uint8List.fromList([...XpubType.xpub.versionBytes, ...payload]),
  );

  group('XpubType.reencode', () {
    test('swaps only the four version bytes', () {
      final zpub = XpubType.zpub.reencode(xpub);

      expect(zpub, startsWith('zpub'));
      final decoded = base58.decode(zpub);
      expect(decoded.sublist(0, 4), XpubType.zpub.versionBytes);
      expect(decoded.sublist(4), payload);
    });

    test('round-trips through every format', () {
      var key = xpub;
      for (final type in XpubType.values) {
        key = type.reencode(key);
      }
      expect(XpubType.xpub.reencode(key), xpub);
    });

    test('is a relabelling, not a re-derivation', () {
      // The same key under two formats decodes to the same payload.
      final a = base58.decode(XpubType.ypub.reencode(xpub)).sublist(4);
      final b = base58.decode(XpubType.vpub.reencode(xpub)).sublist(4);
      expect(a, b);
    });

    test('rejects input that is not base58check', () {
      expect(() => XpubType.zpub.reencode('not a key'), throwsA(anything));
      // Valid base58, wrong checksum: bs58check must refuse it rather
      // than relabel garbage.
      final corrupted = '${xpub.substring(0, xpub.length - 1)}1';
      expect(() => XpubType.zpub.reencode(corrupted), throwsA(anything));
    });
  });
}
