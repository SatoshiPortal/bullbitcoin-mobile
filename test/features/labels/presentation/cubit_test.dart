import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/application/usecases/export_labels_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/import_labels_usecase.dart';
import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';
import 'package:bb_mobile/features/labels/presentation/cubit.dart';
import 'package:bb_mobile/features/labels/frameworks/bip329_codec.dart';
import 'package:bb_mobile/features/labels/presentation/state.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockExport extends Mock implements ExportLabelsUsecase {}

class _MockImport extends Mock implements ImportLabelsUsecase {}

class _MockFilePicker extends Mock implements FilePicker {}

void main() {
  late _MockExport export;
  late _MockImport import;
  late _MockFilePicker picker;

  setUp(() {
    export = _MockExport();
    import = _MockImport();
    picker = _MockFilePicker();
    registerFallbackValue(FormattedLabelsBIP329(jsonl: ''));
    registerFallbackValue(LabelFormat.bip329);
  });

  Bip329LabelsCubit buildCubit() => Bip329LabelsCubit(
    exportLabelsUsecase: export,
    importLabelsUsecase: import,
    filePicker: picker,
  );

  void pickReturns(FilePickerResult? result) =>
      when(() => picker.pickFiles()).thenAnswer((_) async => result);

  Future<PlatformFile> writeFile(List<int> bytes) async {
    final dir = await Directory.systemTemp.createTemp('labels_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/labels.jsonl');
    await file.writeAsBytes(bytes);
    return PlatformFile(
      name: 'labels.jsonl',
      path: file.path,
      size: bytes.length,
    );
  }

  group('import from file', () {
    test('opens the picker without a type filter', () async {
      // FileType.custom with no extensions is refused by the iOS picker,
      // which used to make the import button do nothing at all.
      pickReturns(null);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.importLabelsFromFile(LabelFormat.bip329);

      verify(() => picker.pickFiles()).called(1);
    });

    test('a dismissed picker is not a failure', () async {
      pickReturns(null);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.importLabelsFromFile(LabelFormat.bip329);

      expect(cubit.state, const Bip329LabelsState.initial());
      verifyNever(() => import.call(any()));
    });

    test('a picker that throws is reported, not swallowed', () async {
      when(
        () => picker.pickFiles(),
      ).thenThrow(PlatformException(code: 'Unsupported file extension'));
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.importLabelsFromFile(LabelFormat.bip329);

      expect(
        (cubit.state as Bip329LabelsFailureState).failure,
        isA<LabelUnexpectedFailure>(),
      );
    });

    test('an oversized file is reported without being read', () async {
      pickReturns(
        FilePickerResult([
          PlatformFile(
            name: 'big.jsonl',
            path: '/does/not/exist',
            size: Bip329LabelsCodec.maxImportBytes + 1,
          ),
        ]),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.importLabelsFromFile(LabelFormat.bip329);

      final failure = (cubit.state as Bip329LabelsFailureState).failure;
      expect(
        (failure as LabelsFileTooLargeFailure).maxBytes,
        Bip329LabelsCodec.maxImportBytes,
      );
      verifyNever(() => import.call(any()));
    });

    test('a file that is not text reads as the wrong file', () async {
      pickReturns(
        FilePickerResult([
          await writeFile([0xff, 0xfe, 0xfd]),
        ]),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.importLabelsFromFile(LabelFormat.bip329);

      expect(
        (cubit.state as Bip329LabelsFailureState).failure,
        isA<LabelsFileUnreadableFailure>(),
      );
      verifyNever(() => import.call(any()));
    });

    test('imports the picked file content', () async {
      const jsonl = '{"type":"tx","ref":"abc","label":"rent"}';
      pickReturns(FilePickerResult([await writeFile(utf8.encode(jsonl))]));
      when(() => import.call(any())).thenAnswer((_) async => const Ok(1));
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.importLabelsFromFile(LabelFormat.bip329);

      final passed =
          verify(() => import.call(captureAny())).captured.single
              as FormattedLabelsBIP329;
      expect(passed.jsonl, jsonl);
      expect((cubit.state as Bip329LabelsImportSuccess).labelsCount, 1);
    });
  });

  group('import', () {
    test('forwards the specific failure rather than collapsing it', () async {
      // The cubit used to catch a thrown string and emit
      // LabelUnexpectedFailure, so every bad file read "Oops".
      when(
        () => import.call(any()),
      ).thenAnswer((_) async => const Err(LabelsFileUnreadableFailure()));
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.importLabels(format: LabelFormat.bip329, data: 'nonsense');

      final state = cubit.state as Bip329LabelsFailureState;
      expect(state.failure, isA<LabelsFileUnreadableFailure>());
    });

    test('reports the count on success', () async {
      when(() => import.call(any())).thenAnswer((_) async => const Ok(7));
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.importLabels(format: LabelFormat.bip329, data: '{}');

      expect((cubit.state as Bip329LabelsImportSuccess).labelsCount, 7);
    });
  });

  group('export', () {
    test(
      'forwards the use-case failure without reaching the file picker',
      () async {
        when(
          () => export.call(any()),
        ).thenAnswer((_) async => const Err(LabelsExportFailure()));
        final cubit = buildCubit();
        addTearDown(cubit.close);

        await cubit.exportLabels(LabelFormat.bip329);

        expect(
          (cubit.state as Bip329LabelsFailureState).failure,
          isA<LabelsExportFailure>(),
        );
      },
    );
  });
}
