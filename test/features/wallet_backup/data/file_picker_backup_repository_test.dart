import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/data/file_picker_wallet_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Picker extends Mock implements FilePicker {}

void main() {
  late _Picker picker;
  late FilePickerWalletBackupRepository repository;
  setUpAll(() => registerFallbackValue(Uint8List(0)));
  setUp(() {
    picker = _Picker();
    repository = FilePickerWalletBackupRepository(picker);
  });
  void selected(PlatformFile? file) => when(
    () => picker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: false,
      withReadStream: true,
    ),
  ).thenAnswer((_) async => file == null ? null : FilePickerResult([file]));

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
        PlatformFile(
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
      PlatformFile(
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

      selected(
        PlatformFile(name: 'backup.json', size: 1, readStream: source()),
      );
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
  test(
    'a path fallback stays bounded when the platform cannot stream',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'bull-file-fixture-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/backup.json');
      await file.writeAsString('fixture');
      selected(PlatformFile(name: 'backup.json', path: file.path, size: 0));
      expect(
        (await repository.pick() as Ok<String?, WalletBackupFailure>).value,
        'fixture',
      );
    },
  );
  test('bad UTF8 and unavailable files return typed failures', () async {
    selected(
      PlatformFile(
        name: 'backup.json',
        size: 1,
        readStream: Stream.value([255]),
      ),
    );
    expect(await repository.pick(), isA<Err>());
    selected(PlatformFile(name: 'backup.json', size: 0));
    expect(await repository.pick(), isA<Err>());
  });
  test(
    'save passes exact bytes, preserves cancellation, and rejects oversized output',
    () async {
      Uint8List? saved;
      when(
        () => picker.saveFile(
          fileName: 'bullbitcoin-data-backup-readable.json',
          bytes: any(named: 'bytes'),
        ),
      ).thenAnswer((call) async {
        saved = call.namedArguments[#bytes] as Uint8List;
        return null;
      });
      expect(
        (await repository.save('café', format: WalletBackupFileFormat.readable)
                as Ok<bool, WalletBackupFailure>)
            .value,
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
          fileName: 'bullbitcoin-data-backup-readable.json',
          bytes: any(named: 'bytes'),
        ),
      ).called(1);
    },
  );
}
