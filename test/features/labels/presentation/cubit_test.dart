import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/application/usecases/export_labels_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/import_labels_usecase.dart';
import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';
import 'package:bb_mobile/features/labels/presentation/cubit.dart';
import 'package:bb_mobile/features/labels/presentation/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockExport extends Mock implements ExportLabelsUsecase {}

class _MockImport extends Mock implements ImportLabelsUsecase {}

void main() {
  late _MockExport export;
  late _MockImport import;

  setUp(() {
    export = _MockExport();
    import = _MockImport();
    registerFallbackValue(FormattedLabelsBIP329(jsonl: ''));
    registerFallbackValue(LabelFormat.bip329);
  });

  Bip329LabelsCubit buildCubit() => Bip329LabelsCubit(
    exportLabelsUsecase: export,
    importLabelsUsecase: import,
  );

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
