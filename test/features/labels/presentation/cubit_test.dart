import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/application/usecases/export_labels_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/import_labels_from_file_usecase.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';
import 'package:bb_mobile/features/labels/presentation/cubit.dart';
import 'package:bb_mobile/features/labels/presentation/state.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockExport extends Mock implements ExportLabelsUsecase {}

class _MockImportFromFile extends Mock implements ImportLabelsFromFileUsecase {}

class _MockFilePicker extends Mock implements FilePicker {}

const _path = '/tmp/picked/labels.jsonl';

void main() {
  late _MockExport export;
  late _MockImportFromFile importFromFile;
  late _MockFilePicker picker;

  setUp(() {
    export = _MockExport();
    importFromFile = _MockImportFromFile();
    picker = _MockFilePicker();
    registerFallbackValue(LabelFormat.bip329);
    registerFallbackValue(FileType.any);
    when(() => picker.clearTemporaryFiles()).thenAnswer((_) async => true);
  });

  Bip329LabelsCubit buildCubit() => Bip329LabelsCubit(
    exportLabelsUsecase: export,
    importLabelsFromFileUsecase: importFromFile,
    filePicker: picker,
  );

  void pickReturns(FilePickerResult? result) => when(
    () => picker.pickFiles(type: any(named: 'type')),
  ).thenAnswer((_) async => result);

  FilePickerResult picked({String? path = _path}) => FilePickerResult([
    PlatformFile(name: 'labels.jsonl', path: path, size: 10),
  ]);

  void importReturns(Result<int, LabelFailure> result) => when(
    () => importFromFile.execute(
      format: any(named: 'format'),
      path: any(named: 'path'),
    ),
  ).thenAnswer((_) async => result);

  group('import from file', () {
    test('opens the picker without a type filter', () async {
      // FileType.custom with no extensions is refused by the iOS picker,
      // which used to make the import button do nothing at all.
      pickReturns(null);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.importLabelsFromFile(LabelFormat.bip329);

      verify(() => picker.pickFiles(type: FileType.any)).called(1);
    });

    test('a dismissed picker is not a failure', () async {
      pickReturns(null);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.importLabelsFromFile(LabelFormat.bip329);

      expect(cubit.state, const Bip329LabelsState.initial());
      verifyNever(
        () => importFromFile.execute(
          format: any(named: 'format'),
          path: any(named: 'path'),
        ),
      );
    });

    test('a picker that throws is reported, not swallowed', () async {
      when(
        () => picker.pickFiles(type: any(named: 'type')),
      ).thenThrow(PlatformException(code: 'Unsupported file extension'));
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.importLabelsFromFile(LabelFormat.bip329);

      expect(
        (cubit.state as Bip329LabelsFailureState).failure,
        isA<LabelUnexpectedFailure>(),
      );
    });

    test('a picked file without a path is reported', () async {
      pickReturns(picked(path: null));
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.importLabelsFromFile(LabelFormat.bip329);

      expect(
        (cubit.state as Bip329LabelsFailureState).failure,
        isA<LabelUnexpectedFailure>(),
      );
      verify(() => picker.clearTemporaryFiles()).called(1);
    });

    test(
      'hands the picked path to the use-case and reports the count',
      () async {
        pickReturns(picked());
        importReturns(const Ok(3));
        final cubit = buildCubit();
        addTearDown(cubit.close);

        await cubit.importLabelsFromFile(LabelFormat.bip329);

        verify(
          () => importFromFile.execute(format: LabelFormat.bip329, path: _path),
        ).called(1);
        expect((cubit.state as Bip329LabelsImportSuccess).labelsCount, 3);
      },
    );

    test('forwards the specific failure rather than collapsing it', () async {
      pickReturns(picked());
      importReturns(const Err(LabelsFileUnreadableFailure()));
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.importLabelsFromFile(LabelFormat.bip329);

      expect(
        (cubit.state as Bip329LabelsFailureState).failure,
        isA<LabelsFileUnreadableFailure>(),
      );
    });

    test('clears the picked copy after a successful import', () async {
      pickReturns(picked());
      importReturns(const Ok(1));
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.importLabelsFromFile(LabelFormat.bip329);

      verify(() => picker.clearTemporaryFiles()).called(1);
    });

    test('clears the picked copy after a failed import', () async {
      pickReturns(picked());
      importReturns(const Err(LabelsFileEmptyFailure()));
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.importLabelsFromFile(LabelFormat.bip329);

      verify(() => picker.clearTemporaryFiles()).called(1);
    });

    test('a failed cleanup does not mask the import result', () async {
      pickReturns(picked());
      importReturns(const Ok(2));
      when(
        () => picker.clearTemporaryFiles(),
      ).thenThrow(PlatformException(code: 'clear'));
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.importLabelsFromFile(LabelFormat.bip329);

      expect((cubit.state as Bip329LabelsImportSuccess).labelsCount, 2);
    });

    test('a picker without temp files is left alone', () async {
      // Desktop pickers do not implement clearTemporaryFiles, and there is
      // no copy to clear there either.
      pickReturns(picked());
      importReturns(const Ok(2));
      when(
        () => picker.clearTemporaryFiles(),
      ).thenThrow(UnimplementedError('clearTemporaryFiles'));
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.importLabelsFromFile(LabelFormat.bip329);

      expect((cubit.state as Bip329LabelsImportSuccess).labelsCount, 2);
    });

    test('a dismissed picker leaves nothing to clear', () async {
      pickReturns(null);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.importLabelsFromFile(LabelFormat.bip329);

      verifyNever(() => picker.clearTemporaryFiles());
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
