import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:primitives/primitives.dart' show Err, Ok;
import 'package:bb_mobile/features/bullvault/data/bullvault_metadata_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_record_mapper.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_repository_impl.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../bullvault_test_fixture.dart';

class _Picker extends Mock implements FilePickerPlatform {}

final class _File extends PlatformFile {
  @override
  final String name;
  final int size;
  final Stream<List<int>> readStream;
  _File({required this.name, required this.size, required this.readStream});
  @override
  int lengthSync() => size;
  @override
  Stream<Uint8List> readAsByteStream() => readStream.map(Uint8List.fromList);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SqliteDatabase database;
  late _Picker picker;
  late BullVaultRepositoryImpl repository;
  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    picker = _Picker();
    final codec = testBullVaultRecoveryPackageCodec();
    repository = BullVaultRepositoryImpl(
      BullVaultMetadataDatasource(database),
      BullVaultRecordMapper(codec),
      codec,
      filePicker: picker,
    );
  });
  tearDown(() => database.close());
  void selected(PlatformFile? file) => when(
    () => picker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'txt'],
    ),
  ).thenAnswer((_) async => file == null ? [] : [file]);
  test('cancel leaves verification to the caller without a failure', () async {
    selected(null);
    expect(
      (await repository.pickRecoveryFile() as Ok<String?, BullVaultFailure>)
          .value,
      isNull,
    );
  });
  test('reads a saved descriptor with split UTF8 chunks', () async {
    final bytes = utf8.encode('descriptor café');
    selected(
      _File(
        name: 'vault.txt',
        size: bytes.length,
        readStream: Stream.fromIterable([
          bytes.sublist(0, bytes.length - 1),
          bytes.sublist(bytes.length - 1),
        ]),
      ),
    );
    expect(
      (await repository.pickRecoveryFile() as Ok<String?, BullVaultFailure>)
          .value,
      'descriptor café',
    );
  });
  test('rejects a lying size and cancels the stream at the bound', () async {
    var readPastLimit = false;
    Stream<List<int>> content() async* {
      yield List.filled(1024 * 1024 + 1, 32);
      readPastLimit = true;
      yield [32];
    }

    selected(_File(name: 'vault.txt', size: 1, readStream: content()));
    expect(await repository.pickRecoveryFile(), isA<Err>());
    expect(readPastLimit, isFalse);
  });
  test('invalid UTF8 and picker failure return safe errors', () async {
    selected(
      _File(name: 'vault.txt', size: 2, readStream: Stream.value([0xff, 0xfe])),
    );
    expect(await repository.pickRecoveryFile(), isA<Err>());
    when(
      () => picker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
      ),
    ).thenThrow(Exception('platform error'));
    expect(await repository.pickRecoveryFile(), isA<Err>());
  });
}
