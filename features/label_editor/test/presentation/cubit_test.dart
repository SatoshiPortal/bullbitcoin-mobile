import 'dart:convert';

import 'package:file_system/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:label_editor/src/domain/export_labels_to_file_usecase.dart';
import 'package:label_editor/src/domain/import_labels_from_file_usecase.dart';
import 'package:labels/labels.dart';
import 'package:label_editor/src/presentation/cubit.dart';
import 'package:label_editor/src/presentation/state.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLabels extends Mock implements LabelsFacade {}

class _MockExport extends Mock implements ExportLabelsToFileUsecase {}

class _MockFilePicker extends Mock implements FilePickerPlatform {}

final class _PickedFile extends PlatformFile {
  @override
  final String? path;

  _PickedFile(this.path);

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(utf8.encode('{}'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _path = '/tmp/picked/labels.jsonl';

void main() {
  late _MockExport export;
  late _MockFilePicker picker;

  late _MockLabels labels;

  setUp(() {
    labels = _MockLabels();
    export = _MockExport();
    when(() => labels.maxImportBytes(LabelFormat.bip329)).thenReturn(42);
    picker = _MockFilePicker();
    registerFallbackValue(LabelFormat.bip329);
    registerFallbackValue(FileType.any);
    when(() => picker.clearTemporaryFiles()).thenAnswer((_) async {});
  });

  Bip329LabelsCubit buildCubit() => Bip329LabelsCubit(
    exportLabelsUsecase: export,
    importLabelsFromFileUsecase: ImportLabelsFromFileUsecase(
      fileSystem: openFileSystemForTesting(picker: picker),
      labels: labels,
    ),
  );

  void pickReturns(PlatformFile? result) =>
      when(() => picker.pickFile(type: any(named: 'type')))
          .thenAnswer((_) async => result);

  PlatformFile picked({String? path = _path}) => _PickedFile(path);

  void importReturns(Result<int, LabelFailure> result) =>
      when(() => labels.importLabels(any(), LabelFormat.bip329))
          .thenAnswer((_) async => result);

  group('import from file', () {
    test('opens the picker without a type filter', () async {
      // FileType.custom with no extensions is refused by the iOS picker,
      // which used to make the import button do nothing at all.
      pickReturns(null);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.importLabelsFromFile(LabelFormat.bip329);

      verify(() => picker.pickFile(type: FileType.any)).called(1);
    });

    test('a dismissed picker is not a failure', () async {
      pickReturns(null);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.importLabelsFromFile(LabelFormat.bip329);

      expect(cubit.state, const Bip329LabelsState.initial());
      verifyNever(() => labels.importLabels(any(), LabelFormat.bip329));
    });

    test('a picker that throws is reported, not swallowed', () async {
      when(() => picker.pickFile(type: any(named: 'type')))
          .thenThrow(PlatformException(code: 'Unsupported file extension'));
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
      'hands the picked content to the use-case and reports the count',
      () async {
        pickReturns(picked());
        importReturns(const Ok(3));
        final cubit = buildCubit();
        addTearDown(cubit.close);

        await cubit.importLabelsFromFile(LabelFormat.bip329);

        final parsed = verify(
          () => labels.importLabels(captureAny(), LabelFormat.bip329),
        ).captured.single;
        expect(parsed, '{}');
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
      when(() => picker.clearTemporaryFiles())
          .thenThrow(PlatformException(code: 'clear'));
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
      when(() => picker.clearTemporaryFiles())
          .thenThrow(UnimplementedError('clearTemporaryFiles'));
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
        when(() => export.execute(any()))
            .thenAnswer((_) async => const Err(LabelsExportFailure()));
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
