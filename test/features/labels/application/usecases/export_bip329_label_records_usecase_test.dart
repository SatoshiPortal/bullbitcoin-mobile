import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/adapters/labels_converter_apadater.dart';
import 'package:bb_mobile/features/labels/application/labels_converter_port.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/application/usecases/export_bip329_label_records_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/fetch_all_labels_usecase.dart';
import 'package:bb_mobile/features/labels/bip329_label_record.dart';
import 'package:bb_mobile/features/labels/domain/decoded_labels.dart';
import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';
import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';
import 'package:bb_mobile/features/labels/domain/new_label.dart';
import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';
import 'package:bb_mobile/features/labels/frameworks/bip329_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLabelsRepository extends Mock implements LabelsRepositoryPort {}

final class _ThrowingLabelsConverter implements LabelsConverterPort {
  @override
  List<NewLabel> convertFromMetadataRecords(List<Bip329LabelRecord> records) =>
      throw UnimplementedError();

  @override
  List<Bip329LabelRecord> convertToMetadataRecords(List<LabelEntity> labels) {
    throw const FormatException('private label text must not reach logs');
  }

  @override
  DecodedLabels convertFrom(FormattedLabels formattedLabels) =>
      throw UnimplementedError();

  @override
  FormattedLabels convertTo({
    required LabelFormat format,
    required List<LabelEntity> labels,
    List<({String walletId, String txId, int vout})> frozen = const [],
  }) => throw UnimplementedError();
}

void main() {
  final txId = 'a' * 64;
  late _MockLabelsRepository repository;

  setUp(() {
    repository = _MockLabelsRepository();
  });

  ExportBip329LabelRecordsUsecase buildUsecase(LabelsConverterPort converter) {
    return ExportBip329LabelRecordsUsecase(
      fetchAllLabels: FetchAllLabelsUsecase(labelRepository: repository),
      converter: converter,
    );
  }

  test('returns complete annotation records without local ids', () async {
    when(() => repository.fetchAll()).thenAnswer(
      (_) async => [
        LabelEntity(
          id: 73,
          type: LabelType.transaction,
          reference: txId,
          label: 'coffee',
          origin: '[d34db33f/84h/0h/0h]',
        ),
      ],
    );
    final usecase = buildUsecase(LabelsConverterAdapter(Bip329LabelsCodec()));

    final result = await usecase.execute();

    expect(result, isA<Ok<List<Bip329LabelRecord>, LabelFailure>>());
    final record =
        (result as Ok<List<Bip329LabelRecord>, LabelFailure>).value.single;
    expect(record.type, 'tx');
    expect(record.reference, txId);
    expect(record.label, 'coffee');
    expect(record.origin, '[d34db33f/84h/0h/0h]');
  });

  test('preserves a storage read failure instead of returning empty', () async {
    when(() => repository.fetchAll()).thenThrow(Exception('database locked'));
    final usecase = buildUsecase(LabelsConverterAdapter(Bip329LabelsCodec()));

    final result = await usecase.execute();

    expect(result, isA<Err<List<Bip329LabelRecord>, LabelFailure>>());
    expect(
      (result as Err<List<Bip329LabelRecord>, LabelFailure>).failure,
      isA<LabelUnexpectedFailure>(),
    );
  });

  test('preserves a codec failure instead of returning empty', () async {
    when(() => repository.fetchAll()).thenAnswer(
      (_) async => [
        LabelEntity(
          id: 1,
          type: LabelType.transaction,
          reference: txId,
          label: 'private',
        ),
      ],
    );
    final usecase = buildUsecase(_ThrowingLabelsConverter());

    final result = await usecase.execute();

    expect(result, isA<Err<List<Bip329LabelRecord>, LabelFailure>>());
  });
}
