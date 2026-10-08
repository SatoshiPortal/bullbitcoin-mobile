import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/application/labels_converter_port.dart';
import 'package:bb_mobile/features/labels/application/usecases/import_labels_from_file_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/import_labels_usecase.dart';
import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';
import 'package:bb_mobile/features/labels/domain/labels_file_port.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _FakeLabelsFile implements LabelsFilePort {
  final Result<String, LabelFailure> result;
  String? readPath;
  int? readMaxBytes;

  _FakeLabelsFile(this.result);

  @override
  Future<Result<String, LabelFailure>> readText(
    String path, {
    required int maxBytes,
  }) async {
    readPath = path;
    readMaxBytes = maxBytes;
    return result;
  }
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
        labelsFile: file,
        labelConverter: converter,
        importLabels: import,
      );

  test('reads with the format limit and imports the content', () async {
    const jsonl = '{"type":"tx","ref":"abc","label":"rent"}';
    final file = _FakeLabelsFile(const Ok(jsonl));
    when(() => import.call(any())).thenAnswer((_) async => const Ok(1));

    final result = await build(
      file,
    ).execute(format: LabelFormat.bip329, path: '/picked/labels.jsonl');

    expect(file.readPath, '/picked/labels.jsonl');
    expect(file.readMaxBytes, _limit);
    final passed =
        verify(() => import.call(captureAny())).captured.single
            as FormattedLabelsBIP329;
    expect(passed.jsonl, jsonl);
    expect((result as Ok<int, LabelFailure>).value, 1);
  });

  test('a read failure is forwarded and nothing is imported', () async {
    final file = _FakeLabelsFile(
      const Err(LabelsFileTooLargeFailure(maxBytes: _limit)),
    );

    final result = await build(
      file,
    ).execute(format: LabelFormat.bip329, path: '/picked/big.jsonl');

    final failure = (result as Err<int, LabelFailure>).failure;
    expect((failure as LabelsFileTooLargeFailure).maxBytes, _limit);
    verifyNever(() => import.call(any()));
  });

  test('an import failure is forwarded as-is', () async {
    final file = _FakeLabelsFile(const Ok('{}'));
    when(
      () => import.call(any()),
    ).thenAnswer((_) async => const Err(LabelsFileEmptyFailure()));

    final result = await build(
      file,
    ).execute(format: LabelFormat.bip329, path: '/picked/labels.jsonl');

    expect(
      (result as Err<int, LabelFailure>).failure,
      isA<LabelsFileEmptyFailure>(),
    );
  });
}
