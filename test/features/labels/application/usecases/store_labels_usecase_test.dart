import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/application/application_label.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/application/store_label_application.dart';
import 'package:bb_mobile/features/labels/application/usecases/store_labels_usecase.dart';
import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:bb_mobile/features/labels/domain/new_label.dart';
import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLabelsRepository extends Mock implements LabelsRepositoryPort {}

class _MockLabelEntity extends Mock implements LabelEntity {}

void main() {
  late _MockLabelsRepository repository;
  late StoreLabelUsecase usecase;

  const newLabel = NewApplicationLabel(
    type: LabelType.transaction,
    label: 'coffee',
    reference: 'txid',
  );

  setUpAll(() {
    registerFallbackValue(
      NewLabel(type: LabelType.transaction, reference: 'txid', label: 'coffee'),
    );
  });

  setUp(() {
    repository = _MockLabelsRepository();
    usecase = StoreLabelUsecase(labelRepository: repository);
  });

  group('StoreLabelUsecase', () {
    test('maps a repository failure to a sanitized LabelFailure '
        'without leaking the raw exception', () async {
      when(
        () => repository.store(any()),
      ).thenThrow(Exception('drift: UNIQUE constraint failed'));

      final result = await usecase.execute(newLabel);

      expect(result, isA<Err<ApplicationLabel, LabelFailure>>());
      expect(
        (result as Err<ApplicationLabel, LabelFailure>).failure,
        isA<LabelUnexpectedFailure>(),
      );
    });

    test('returns Ok with the mapped label on success', () async {
      final stored = _MockLabelEntity();
      when(() => stored.id).thenReturn(1);
      when(() => stored.type).thenReturn(LabelType.transaction);
      when(() => stored.label).thenReturn('coffee');
      when(() => stored.reference).thenReturn('txid');
      when(() => stored.origin).thenReturn(null);
      when(() => repository.store(any())).thenAnswer((_) async => stored);

      final result = await usecase.execute(newLabel);

      expect(result, isA<Ok<ApplicationLabel, LabelFailure>>());
      expect(
        (result as Ok<ApplicationLabel, LabelFailure>).value.label,
        'coffee',
      );
    });
  });
}
