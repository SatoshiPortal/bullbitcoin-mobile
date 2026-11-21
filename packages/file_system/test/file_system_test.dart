import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_system/file_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Picker extends Mock implements FilePickerPlatform {}

final class _Document extends PlatformFile {
  final bool readable;

  _Document({this.readable = true});

  @override
  String get name => 'document.PDF';

  @override
  Stream<Uint8List> readAsByteStream() async* {
    if (!readable) throw const FileSystemException('unreadable test document');
    yield Uint8List.fromList([1, 2, 3]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Picker picker;
  late FileSystem fileSystem;

  setUp(() {
    picker = _Picker();
    fileSystem = FileSystem(picker: picker);
    registerFallbackValue(FileType.any);
  });

  void selects(PlatformFile? document) {
    when(
      () => picker.pickFile(
        type: any(named: 'type'),
        allowedExtensions: any(named: 'allowedExtensions'),
      ),
    ).thenAnswer((_) async => document);
  }

  test('returns the selected document bytes and their actual size', () async {
    selects(_Document());
    final result = await fileSystem.pick(allowedExtensions: ['pdf']);
    switch (result) {
      case Ok(:final value):
        expect(value?.name, 'document.PDF');
        expect(value?.extension, 'PDF');
        if (value == null) fail('a document was selected');
        final read = await fileSystem.read(value, maxBytes: 3);
        expect((read as Ok<Uint8List, FileSystemFailure>).value, [1, 2, 3]);
      case Err():
        fail('the selected readable document should be returned');
    }
  });

  test('cancelled selection returns no document', () async {
    selects(null);
    expect(
      await fileSystem.pick(allowedExtensions: ['pdf']),
      const Ok<PickedDocument?, FileSystemFailure>(null),
    );
  });

  test('a selected unreadable file retains the document failure', () async {
    selects(_Document(readable: false));
    final picked = await fileSystem.pick(allowedExtensions: ['pdf']);
    final document = (picked as Ok<PickedDocument?, FileSystemFailure>).value;
    if (document == null) fail('a document was selected');
    expect(
      await fileSystem.read(document, maxBytes: 3),
      isA<Err<Uint8List, FileSystemFailure>>().having(
        (r) => r.failure.kind,
        'failure kind',
        FileSystemFailureKind.read,
      ),
    );
  });
  test('stops reading when a second chunk exceeds the limit', () async {
    selects(_ChunkedDocument());
    final picked = await fileSystem.pick(allowedExtensions: ['pdf']);
    final document = (picked as Ok<PickedDocument?, FileSystemFailure>).value;
    if (document == null) fail('a document was selected');

    expect(
      await fileSystem.read(document, maxBytes: 3),
      isA<Err<Uint8List, FileSystemFailure>>().having(
        (result) => result.failure.kind,
        'failure kind',
        FileSystemFailureKind.tooLarge,
      ),
    );
  });

  test(
    'save passes the selected filename, bytes and MIME type to the picker',
    () async {
      final bytes = Uint8List.fromList([1, 2]);
      when(
        () => picker.saveFile(
          fileName: 'example.txt',
          bytes: bytes,
          mimeType: 'text/plain',
        ),
      ).thenAnswer((_) async => Uri.file('/export/example.txt'));

      expect(
        (await fileSystem.save(
          filename: 'example.txt',
          bytes: bytes,
          mimeType: 'text/plain',
        ) as Ok<bool, FileSystemFailure>).value,
        isTrue,
      );
    },
  );
}

final class _ChunkedDocument extends PlatformFile {
  @override
  Stream<Uint8List> readAsByteStream() async* {
    yield Uint8List.fromList([1, 2]);
    yield Uint8List.fromList([3, 4]);
    fail('reading should stop before requesting another chunk');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
