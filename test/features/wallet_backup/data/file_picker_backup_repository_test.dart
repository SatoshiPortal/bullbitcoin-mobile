import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:primitives/primitives.dart' show Err, Ok;
import 'package:bb_mobile/features/wallet_backup/data/file_picker_wallet_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Picker extends Mock implements FilePickerPlatform {}

void main() {
  late _Picker picker;
  late FilePickerWalletBackupRepository repository;
  setUpAll(() => registerFallbackValue(Uint8List(0)));
  setUp(() {
    picker = _Picker();
    repository = FilePickerWalletBackupRepository(picker);
  });
  void selected(PlatformFile? file) => when(
    () => picker.pickFiles(type: FileType.custom, allowedExtensions: ['json']),
  ).thenAnswer((_) async => file == null ? [] : [file]);

  test('cancelling the picker is an ordinary empty result', () async {
    selected(null);
    expect(
      (await repository.pick() as Ok<String?, WalletBackupFailure>).value,
      isNull,
    );
  });
  test(
    'requests streaming and combines UTF8 chunks without eager file bytes',
    () async {
      final bytes = utf8.encode('café');
      selected(
        _File(
          name: 'backup.json',
          size: bytes.length,
          readStream: Stream.fromIterable([
            bytes.sublist(0, 4),
            bytes.sublist(4),
          ]),
        ),
      );
      expect(
        (await repository.pick() as Ok<String?, WalletBackupFailure>).value,
        'café',
      );
    },
  );
  test('an oversized advertised size is rejected before subscribing', () async {
    var listened = false;
    final stream = StreamController<List<int>>(onListen: () => listened = true);
    selected(
      _File(
        name: 'backup.json',
        size: WalletBackupFile.maximumBytes + 1,
        readStream: stream.stream,
      ),
    );
    expect(await repository.pick(), isA<Err>());
    expect(listened, isFalse);
    unawaited(stream.close());
  });
  test(
    'stream counting catches a false size and cancels before reading more',
    () async {
      var cancelled = false, reachedThird = false;
      Stream<List<int>> source() async* {
        try {
          yield Uint8List(WalletBackupFile.maximumBytes ~/ 2 + 1);
          yield Uint8List(WalletBackupFile.maximumBytes ~/ 2 + 1);
          reachedThird = true;
          yield [0];
        } finally {
          cancelled = true;
        }
      }

      selected(_File(name: 'backup.json', size: 1, readStream: source()));
      expect(
        await repository.pick(),
        isA<Err<String?, WalletBackupFailure>>().having(
          (e) => e.failure,
          'failure',
          isA<WalletBackupTooLargeFailure>(),
        ),
      );
      expect(cancelled, isTrue);
      expect(reachedThird, isFalse);
    },
  );
  test('bad UTF8 and unavailable files return typed failures', () async {
    selected(
      _File(name: 'backup.json', size: 1, readStream: Stream.value([255])),
    );
    expect(await repository.pick(), isA<Err>());
    selected(_File(name: 'backup.json', size: 0));
    expect(await repository.pick(), isA<Err>());
  });
  test('save passes exact bytes, preserves cancellation, and rejects oversized output', () async {
    Uint8List? saved;
    when(
      () => picker.saveFile(
        mimeType: 'application/json',
        fileName: 'bullbitcoin-data-backup-readable.json',
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer((call) async {
      saved = call.namedArguments[#bytes] as Uint8List;
      return null;
    });
    expect(
      (await repository.save(
        'café',
        format: WalletBackupFileFormat.readable,
      ) as Ok<bool, WalletBackupFailure>).value,
      isFalse,
    );
    expect(saved, utf8.encode('café'));
    expect(
      await repository.save(
        'x' * (WalletBackupFile.maximumBytes + 1),
        format: WalletBackupFileFormat.readable,
      ),
      isA<Err>(),
    );
    verify(
      () => picker.saveFile(
        mimeType: 'application/json',
        fileName: 'bullbitcoin-data-backup-readable.json',
        bytes: any(named: 'bytes'),
      ),
    ).called(1);
  });
}

final class _File extends PlatformFile {
  @override
  final String name;
  final int size;
  final Stream<List<int>>? readStream;
  _File({required this.name, required this.size, this.readStream});
  @override
  int lengthSync() => size;
  @override
  Stream<Uint8List> readAsByteStream() {
    final source = readStream;
    if (source == null) throw const FormatException('File unavailable');
    return source.map(Uint8List.fromList);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
