import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/application/usecases/trash_label_usecase.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLabelsRepository extends Mock implements LabelsRepositoryPort {}

void main() {
  late _MockLabelsRepository repository;
  late TrashLabelUsecase usecase;

  setUp(() {
    repository = _MockLabelsRepository();
    usecase = TrashLabelUsecase(labelRepository: repository);
  });

  group('TrashLabelUsecase', () {
    test('maps a repository failure to a sanitized LabelFailure '
        'without leaking the raw exception', () async {
      when(() => repository.trash(any())).thenThrow(Exception('db locked'));

      final result = await usecase.execute(42);

      expect(result, isA<Err<Null, LabelFailure>>());
      expect(
        (result as Err<Null, LabelFailure>).failure,
        isA<LabelUnexpectedFailure>(),
      );
    });

    test('returns Ok on success', () async {
      when(() => repository.trash(any())).thenAnswer((_) async {});

      final result = await usecase.execute(42);

      expect(result, isA<Ok<Null, LabelFailure>>());
    });
  });
}
