import 'dart:convert';
import 'dart:typed_data';

import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/labels/application/labels_converter_port.dart';
import 'package:bb_mobile/features/labels/application/usecases/import_labels_from_file_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/import_labels_usecase.dart';
import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';
import 'package:file_system/file_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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

class _MockConverter extends Mock implements LabelsConverterPort {}

class _MockImport extends Mock implements ImportLabelsUsecase {}

const _limit = 42;

void main() {
  late _MockConverter converter;
  late _MockImport import;

  setUp(() {
    converter = _MockConverter();
    import = _MockImport();
    registerFallbackValue(FormattedLabelsBIP329(jsonl: ''));
    when(() => converter.maxImportBytes(LabelFormat.bip329)).thenReturn(_limit);
  });

  ImportLabelsFromFileUsecase build(_FakeLabelsFile file) =>
      ImportLabelsFromFileUsecase(
        fileSystem: file,
        labelConverter: converter,
        importLabels: import,
      );

  test('reads with the format limit and imports the content', () async {
    const jsonl = '{"type":"tx","ref":"abc","label":"rent"}';
    final file = _FakeLabelsFile(Ok(utf8.encode(jsonl)));
    when(() => import.call(any())).thenAnswer((_) async => const Ok(1));

    final result = await build(file)
        .execute(format: LabelFormat.bip329, onPicked: () {});

    expect(file.readDocument, same(file.document));
    expect(file.readMaxBytes, _limit);
    final passed =
        verify(() => import.call(captureAny())).captured.single
            as FormattedLabelsBIP329;
    expect(passed.jsonl, jsonl);
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
    verifyNever(() => import.call(any()));
  });

  test('a file that is not UTF-8 is rejected before import', () async {
    final file = _FakeLabelsFile(Ok(Uint8List.fromList([0xff, 0xfe, 0xfd])));
    final result = await build(file)
        .execute(format: LabelFormat.bip329, onPicked: () {});

    expect(
      (result as Err<int?, LabelFailure>).failure,
      isA<LabelsFileUnreadableFailure>(),
    );
    verifyNever(() => import.call(any()));
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
    verifyNever(() => import.call(any()));
  });

  test('an import failure is forwarded as-is', () async {
    final file = _FakeLabelsFile(Ok(utf8.encode('{}')));
    when(() => import.call(any()))
        .thenAnswer((_) async => const Err(LabelsFileEmptyFailure()));

    final result = await build(file)
        .execute(format: LabelFormat.bip329, onPicked: () {});

    expect(
      (result as Err<int?, LabelFailure>).failure,
      isA<LabelsFileEmptyFailure>(),
    );
  });
}
