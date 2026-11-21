import 'package:primitives/primitives.dart';
import 'package:labels/src/domain/application_label.dart';
import 'package:labels/src/domain/labels_repository_port.dart';
import 'package:labels/src/domain/usecases/fetch_labels_usecase.dart';
import 'package:labels/src/domain/label_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLabelsRepository extends Mock implements LabelsRepositoryPort {}

void main() {
  late _MockLabelsRepository repository;
  late FetchLabelsUsecase usecase;

  setUp(() {
    repository = _MockLabelsRepository();
    usecase = FetchLabelsUsecase(repository);
  });

  group('FetchLabelsUsecase', () {
    test('maps a repository failure to a sanitized LabelFailure '
        'without leaking the raw exception', () async {
      when(() => repository.fetchAll())
          .thenThrow(Exception('drift: database is locked at /data/secret.db'));

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
    test('maps a reference lookup failure to a sanitized LabelFailure '
        'without leaking the raw exception', () async {
      when(() => repository.fetchByReference(any()))
          .thenThrow(Exception('drift failure exposing an on-chain reference'));

      final result = await usecase.execute(reference: 'some-address');

      expect(result, isA<Err<List<ApplicationLabel>, LabelFailure>>());
      expect(
        (result as Err<List<ApplicationLabel>, LabelFailure>).failure,
        isA<LabelUnexpectedFailure>(),
      );
    });

    test(
      'returns Ok with no labels when the reference does not match',
      () async {
        when(() => repository.fetchByReference(any()))
            .thenAnswer((_) async => []);

        final result = await usecase.execute(reference: 'some-address');

        expect(result, isA<Ok<List<ApplicationLabel>, LabelFailure>>());
        expect(
          (result as Ok<List<ApplicationLabel>, LabelFailure>).value,
          isEmpty,
        );
      },
    );
  });
}
