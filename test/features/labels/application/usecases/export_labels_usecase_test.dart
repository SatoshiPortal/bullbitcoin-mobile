import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/application/labels_converter_port.dart';
import 'package:bb_mobile/features/labels/application/labels_converter_port_registry.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/application/usecases/export_labels_usecase.dart';
import 'package:bb_mobile/features/labels/application/wallet_freeze_port.dart';
import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements LabelsRepositoryPort {}

class _MockWalletFreeze extends Mock implements WalletFreezePort {}

class _StubConverter implements LabelsConverterPort {
  @override
  FormattedLabels convertTo({
    required format,
    required labels,
    frozen = const [],
  }) => FormattedLabelsBIP329(jsonl: '{"type":"tx"}');

  @override
  convertFrom(FormattedLabels labels) => throw UnimplementedError();
}

void main() {
  late _MockRepository repository;
  late _MockWalletFreeze walletFreeze;
  late ExportLabelsUsecase usecase;

  setUp(() {
    repository = _MockRepository();
    walletFreeze = _MockWalletFreeze();
    usecase = ExportLabelsUsecase(
      labelRepository: repository,
      converterRegistry: LabelsConverterPortRegistry({
        LabelFormat.bip329: _StubConverter(),
      }),
      walletFreeze: walletFreeze,
    );
    when(() => walletFreeze.getAllFrozen()).thenAnswer((_) async => []);
  });

  test('returns the serialized labels', () async {
    when(() => repository.fetchAll()).thenAnswer((_) async => []);

    final result = await usecase.call(LabelFormat.bip329);

    expect((result as Ok<String, LabelFailure>).value, '{"type":"tx"}');
  });

  test('a failed read becomes a typed failure carrying no reason: the reason '
      "quotes the user's own label text", () async {
    when(
      () => repository.fetchAll(),
    ).thenThrow(Exception('drift: row "rent to Alice Smith"'));

    final result = await usecase.call(LabelFormat.bip329);

    switch (result) {
      case Ok():
        fail('a failed read must not be reported as an export');
      case Err(:final failure):
        expect(failure, isA<LabelsExportFailure>());
        expect(failure.logMessage, isNull);
        expect(failure.toString(), isNot(contains('Alice Smith')));
    }
  });

  test('a failed freeze read is also contained', () async {
    when(() => repository.fetchAll()).thenAnswer((_) async => []);
    when(() => walletFreeze.getAllFrozen()).thenThrow(Exception('boom'));

    final result = await usecase.call(LabelFormat.bip329);

    expect(result, isA<Err<String, LabelFailure>>());
  });
}
