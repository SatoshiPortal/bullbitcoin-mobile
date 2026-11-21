import 'dart:convert';
import 'dart:typed_data';

import 'package:primitives/primitives.dart';
import 'package:label_editor/src/domain/import_labels_from_file_usecase.dart';
import 'package:labels/labels.dart';
import 'package:file_system/file_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLabels extends Mock implements LabelsFacade {}

class _Document extends Fake implements PickedDocument {
  @override
  String get path => '/picked/labels.jsonl';
}

class _FakeLabelsFile extends Fake implements FileSystem {
  final Result<Uint8List, FileSystemFailure> result;
  final document = _Document();
  PickedDocument? readDocument;
  int? readMaxBytes;

  _FakeLabelsFile(this.result);

  @override
  Future<Result<PickedDocument?, FileSystemFailure>> pick({
    List<String> allowedExtensions = const [],
  }) async => Ok(document);

  @override
  Future<Result<Uint8List, FileSystemFailure>> read(
    PickedDocument document, {
    required int maxBytes,
  }) async {
    readDocument = document;
    readMaxBytes = maxBytes;
    return result;
  }

  @override
  Future<Result<void, FileSystemFailure>> clearTemporaryFiles() async =>
      const Ok(null);
}

const _limit = 42;

void main() {
  late _MockLabels labels;

  setUp(() {
    labels = _MockLabels();
    when(() => labels.maxImportBytes(LabelFormat.bip329)).thenReturn(_limit);
  });

  ImportLabelsFromFileUsecase build(_FakeLabelsFile file) =>
      ImportLabelsFromFileUsecase(fileSystem: file, labels: labels);

  test('reads with the format limit and imports the content', () async {
    const jsonl = '{"type":"tx","ref":"abc","label":"rent"}';
    final file = _FakeLabelsFile(Ok(utf8.encode(jsonl)));
    when(() => labels.importLabels(any(), LabelFormat.bip329))
        .thenAnswer((_) async => const Ok(1));

    final result = await build(file)
        .execute(format: LabelFormat.bip329, onPicked: () {});

    expect(file.readDocument, same(file.document));
    expect(file.readMaxBytes, _limit);
    final passed = verify(
      () => labels.importLabels(captureAny(), LabelFormat.bip329),
    ).captured.single;
    expect(passed, jsonl);
    expect((result as Ok<int?, LabelFailure>).value, 1);
  });

  test('a read failure is forwarded and nothing is imported', () async {
    final file = _FakeLabelsFile(
      const Err(FileSystemFailure(FileSystemFailureKind.tooLarge)),
    );

    final result = await build(file)
        .execute(format: LabelFormat.bip329, onPicked: () {});

    final failure = (result as Err<int?, LabelFailure>).failure;
    expect((failure as LabelsFileTooLargeFailure).maxBytes, _limit);
    verifyNever(() => labels.importLabels(any(), LabelFormat.bip329));
  });

  test('a file that is not UTF-8 is rejected before import', () async {
    final file = _FakeLabelsFile(Ok(Uint8List.fromList([0xff, 0xfe, 0xfd])));
    final result = await build(file)
        .execute(format: LabelFormat.bip329, onPicked: () {});

    expect(
      (result as Err<int?, LabelFailure>).failure,
      isA<LabelsFileUnreadableFailure>(),
    );
    verifyNever(() => labels.importLabels(any(), LabelFormat.bip329));
  });

  test('a missing file maps to an unexpected failure', () async {
    final file = _FakeLabelsFile(
      const Err(FileSystemFailure(FileSystemFailureKind.missing)),
    );
    final result = await build(file)
        .execute(format: LabelFormat.bip329, onPicked: () {});

    expect(
      (result as Err<int?, LabelFailure>).failure,
      isA<LabelUnexpectedFailure>(),
    );
    verifyNever(() => labels.importLabels(any(), LabelFormat.bip329));
  });

  test('an import failure is forwarded as-is', () async {
    final file = _FakeLabelsFile(Ok(utf8.encode('{}')));
    when(() => labels.importLabels(any(), LabelFormat.bip329))
        .thenAnswer((_) async => const Err(LabelsFileEmptyFailure()));

    final result = await build(file)
        .execute(format: LabelFormat.bip329, onPicked: () {});

    expect(
      (result as Err<int?, LabelFailure>).failure,
      isA<LabelsFileEmptyFailure>(),
    );
  });
}
