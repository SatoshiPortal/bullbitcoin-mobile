import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/adapters/labels_converter_apadater.dart';
import 'package:bb_mobile/features/labels/application/application_label.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/application/usecases/export_bip329_label_records_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/fetch_all_labels_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/fetch_label_by_reference_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/store_labels_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/restore_bip329_label_records_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/trash_label_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/watch_label_changes_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/labels/frameworks/bip329_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFetchLabelByReferenceUsecase extends Mock
    implements FetchLabelByReferenceUsecase {}

class _MockFetchAllLabelsUsecase extends Mock
    implements FetchAllLabelsUsecase {}

class _MockStoreLabelUsecase extends Mock implements StoreLabelUsecase {}

class _MockTrashLabelUsecase extends Mock implements TrashLabelUsecase {}

class _MockLabelsRepository extends Mock implements LabelsRepositoryPort {}

void main() {
  test(
    'strict backup export preserves a failure at the public boundary',
    () async {
      final fetchAll = _MockFetchAllLabelsUsecase();
      when(() => fetchAll.execute()).thenAnswer(
        (_) async => const Err<List<ApplicationLabel>, LabelFailure>(
          LabelUnexpectedFailure(),
        ),
      );
      final export = ExportBip329LabelRecordsUsecase(
        fetchAllLabels: fetchAll,
        converter: LabelsConverterAdapter(Bip329LabelsCodec()),
      );
      final repository = _MockLabelsRepository();
      final facade = LabelsFacade(
        fetchLabelByReferenceUsecase: _MockFetchLabelByReferenceUsecase(),
        fetchAllLabelsUsecase: fetchAll,
        storeLabelsUsecase: _MockStoreLabelUsecase(),
        trashLabelUsecase: _MockTrashLabelUsecase(),
        exportBip329LabelRecordsUsecase: export,
        restoreBip329LabelRecordsUsecase: RestoreBip329LabelRecordsUsecase(
          repository,
          LabelsConverterAdapter(Bip329LabelsCodec()),
        ),
        watchLabelChangesUsecase: WatchLabelChangesUsecase(repository),
      );

      final result = await facade.exportBip329LabelRecords();

      expect(result, isA<Err<List<Bip329LabelRecord>, LabelFailure>>());
      verify(() => fetchAll.execute()).called(1);
    },
  );
}
