import 'dart:convert';

import 'package:bb_mobile/features/scan_anything/domain/bbqr_assembler.dart';
import 'package:bb_mobile/features/scan_anything/domain/scan_anything_failure.dart';
import 'package:bb_mobile/features/scan_anything/domain/usecases/decode_bbqr_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show Err, Ok;

void main() {
  test('collects the parts in order and reports progress', () {
    final assembler = BbqrAssembler();

    expect(BbqrAssembler.isPart(r'B$2P0201BBBB'), isTrue);
    expect(BbqrAssembler.isPart('bitcoin:address'), isFalse);

    final first = assembler.add(r'B$2P0201BBBB');
    expect(first.received, 1);
    expect(first.total, 2);
    expect(first.isComplete, isFalse);

    final again = assembler.add(r'B$2P0201BBBB');
    expect(again.received, 1);

    final last = assembler.add(r'B$2P0200AAAA');
    expect(last.type, 'P');
    expect(last.completeParts, [r'B$2P0200AAAA', r'B$2P0201BBBB']);
  });

  test('a different code restarts the collection', () {
    final assembler = BbqrAssembler()..add(r'B$2P0300AAAA');

    final progress = assembler.add(r'B$2T0200AAAA');

    expect(progress.received, 1);
    expect(progress.total, 2);
  });

  group('DecodeBbqrUsecase', () {
    DecodeBbqrUsecase usecase(List<int> data) =>
        DecodeBbqrUsecase(join: (_) async => data);

    test('a PSBT becomes base64', () async {
      final result = await usecase([1, 2, 3]).execute(parts: [], type: 'P');
      expect((result as Ok).value, base64.encode([1, 2, 3]));
    });

    test('a transaction becomes hex', () async {
      final result = await usecase([1, 255]).execute(parts: [], type: 'T');
      expect((result as Ok).value, '01ff');
    });

    test('text stays text', () async {
      final result = await usecase(
        utf8.encode('wpkh(xpub)'),
      ).execute(parts: [], type: 'U');
      expect((result as Ok).value, 'wpkh(xpub)');
    });

    test('other types and join errors are not recognized', () async {
      final binary = await usecase([1]).execute(parts: [], type: 'B');
      expect((binary as Err).failure, isA<ScanAnythingUnrecognizedFailure>());

      final broken = await DecodeBbqrUsecase(
        join: (_) async => throw Exception('bad'),
      ).execute(parts: [], type: 'P');
      expect((broken as Err).failure, isA<ScanAnythingUnrecognizedFailure>());
    });
  });
}
