import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/application/application_label.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/application/usecases/fetch_all_labels_usecase.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLabelsRepository extends Mock implements LabelsRepositoryPort {}

void main() {
  late _MockLabelsRepository repository;
  late FetchAllLabelsUsecase usecase;

  setUp(() {
    repository = _MockLabelsRepository();
    usecase = FetchAllLabelsUsecase(labelRepository: repository);
  });

  group('FetchAllLabelsUsecase', () {
    test('maps a repository failure to a sanitized LabelFailure '
        'without leaking the raw exception', () async {
      when(
        () => repository.fetchAll(),
      ).thenThrow(Exception('drift: database is locked at /data/secret.db'));

      final result = await usecase.execute();

      expect(result, isA<Err<List<ApplicationLabel>, LabelFailure>>());
      expect(
        (result as Err<List<ApplicationLabel>, LabelFailure>).failure,
        isA<LabelUnexpectedFailure>(),
      );
    });

    test('returns Ok with the mapped labels on success', () async {
      when(() => repository.fetchAll()).thenAnswer((_) async => []);

      final result = await usecase.execute();

      expect(result, isA<Ok<List<ApplicationLabel>, LabelFailure>>());
      expect(
        (result as Ok<List<ApplicationLabel>, LabelFailure>).value,
        isEmpty,
      );
    });
  });
}
