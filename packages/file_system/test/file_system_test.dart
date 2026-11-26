import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_system/file_system.dart';
import 'package:file_system/testing.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Picker extends Mock implements FilePickerPlatform {}

final class _Document extends PlatformFile {
  final Object? readError;

  _Document({this.readError});

  @override
  String get name => 'document.PDF';

  @override
  Stream<Uint8List> readAsByteStream() async* {
    if (readError case final Object error) throw error;
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
    fileSystem = openFileSystemForTesting(picker: picker);
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

  void testErrorBoundary<T>(
    String operation,
    Matcher failure,
    Future<Result<T, FileSystemFailure>> Function(Object error) invoke,
  ) {
    test('$operation maps a platform exception to a typed failure', () async {
      expect(
        await invoke(PlatformException(code: 'picker-failed')),
        isA<Err<T, FileSystemFailure>>().having(
          (result) => result.failure,
          'failure',
          failure,
        ),
      );
    });

    test('$operation propagates a programmer error', () async {
      final error = StateError('invalid picker state');
      await expectLater(invoke(error), throwsA(same(error)));
    });
  }

  testErrorBoundary('pick', isA<FileSystemPickFailure>(), (error) {
    when(() => picker.pickFile(type: FileType.any)).thenThrow(error);
    return fileSystem.pick();
  });

  testErrorBoundary('read', isA<FileSystemReadFailure>(), (error) async {
    selects(_Document(readError: error));
    final document = (await fileSystem.pick(allowedExtensions: ['pdf'])).fold(
      (document) => document ?? fail('a document was expected'),
      (_) => fail('could not select the document'),
    );
    return fileSystem.read(document, maxBytes: 3);
  });

  testErrorBoundary('save', isA<FileSystemSaveFailure>(), (error) {
    final bytes = Uint8List(0);
    when(
      () => picker.saveFile(
        fileName: 'example.txt',
        bytes: bytes,
        mimeType: 'application/octet-stream',
      ),
    ).thenThrow(error);
    return fileSystem.save(filename: 'example.txt', bytes: bytes);
  });

  testErrorBoundary('cleanup', isA<FileSystemCleanupFailure>(), (error) {
    when(() => picker.clearTemporaryFiles()).thenThrow(error);
    return fileSystem.clearTemporaryFiles();
  });

  test(
    'cleanup succeeds on a platform without temporary-file support',
    () async {
      when(() => picker.clearTemporaryFiles()).thenThrow(UnimplementedError());
      expect(
        await fileSystem.clearTemporaryFiles(),
        isA<Ok<void, FileSystemFailure>>(),
      );
    },
  );

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
    selects(
      _Document(
        readError: const FileSystemException('unreadable test document'),
      ),
    );
    final picked = await fileSystem.pick(allowedExtensions: ['pdf']);
    final document = (picked as Ok<PickedDocument?, FileSystemFailure>).value;
    if (document == null) fail('a document was selected');
    expect(
      await fileSystem.read(document, maxBytes: 3),
      isA<Err<Uint8List, FileSystemFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<FileSystemReadFailure>(),
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
        (result) => result.failure,
        'failure',
        isA<FileSystemTooLargeFailure>(),
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

  test('cancelled saving returns Ok(false)', () async {
    final bytes = Uint8List.fromList([1, 2]);
    when(
      () => picker.saveFile(
        fileName: 'example.txt',
        bytes: bytes,
        mimeType: 'application/octet-stream',
      ),
    ).thenAnswer((_) async => null);

    expect(
      await fileSystem.save(filename: 'example.txt', bytes: bytes),
      isA<Ok<bool, FileSystemFailure>>().having(
        (result) => result.value,
        'value',
        isFalse,
      ),
    );
  });
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
