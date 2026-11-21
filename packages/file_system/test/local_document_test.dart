import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_system/file_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Picker extends Mock implements FilePickerPlatform {}

final class _LocalDocument extends PlatformFile {
  final File file;

  _LocalDocument(this.file);

  @override
  Stream<Uint8List> readAsByteStream() =>
      file.openRead().map(Uint8List.fromList);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Picker picker;
  late FileSystem fileSystem;

  setUp(() {
    picker = _Picker();
    fileSystem = FileSystem(picker: picker);
  });

  Future<PickedDocument> selectFile(List<int>? bytes) async {
    final dir = await Directory.systemTemp.createTemp('labels_file_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/labels.jsonl');
    if (bytes != null) await file.writeAsBytes(bytes);
    when(() => picker.pickFile(type: FileType.any))
        .thenAnswer((_) async => _LocalDocument(file));

    return (await fileSystem.pick()).fold(
      (document) => document ?? fail('a document was selected'),
      (_) => fail('could not select the document'),
    );
  }

  test('reads a UTF-8 file', () async {
    const jsonl = '{"type":"tx","ref":"abc","label":"café"}';
    final document = await selectFile(utf8.encode(jsonl));
    final result = await fileSystem.read(document, maxBytes: 1024);
    expect(
      utf8.decode((result as Ok<Uint8List, FileSystemFailure>).value),
      jsonl,
    );
  });

  test('a file over its byte limit is rejected', () async {
    final document = await selectFile(List.filled(11, 0x61));
    final result = await fileSystem.read(document, maxBytes: 10);
    expect(
      (result as Err<Uint8List, FileSystemFailure>).failure.kind,
      FileSystemFailureKind.tooLarge,
    );
  });

  test('a file exactly at the limit is read', () async {
    final document = await selectFile(List.filled(10, 0x61));
    final result = await fileSystem.read(document, maxBytes: 10);
    expect(
      utf8.decode((result as Ok<Uint8List, FileSystemFailure>).value),
      'a' * 10,
    );
  });

  test('reports a document that no longer exists', () async {
    final document = await selectFile(null);
    final result = await fileSystem.read(document, maxBytes: 1024);
    expect(
      (result as Err<Uint8List, FileSystemFailure>).failure.kind,
      FileSystemFailureKind.missing,
    );
  });
}
