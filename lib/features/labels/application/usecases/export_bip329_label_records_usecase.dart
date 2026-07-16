import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/adapters/label_mapper.dart';
import 'package:bb_mobile/features/labels/application/labels_converter_port.dart';
import 'package:bb_mobile/features/labels/application/usecases/fetch_all_labels_usecase.dart';
import 'package:bb_mobile/features/labels/bip329_label_record.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:meta/meta.dart';

final class ExportBip329LabelRecordsUsecase {
  final FetchAllLabelsUsecase _fetchAllLabels;
  final LabelsConverterPort _converter;

  const ExportBip329LabelRecordsUsecase({
    required this._fetchAllLabels,
    required this._converter,
  });

  @useResult
  Future<Result<List<Bip329LabelRecord>, LabelFailure>> execute() async {
    final result = await _fetchAllLabels.execute();
    return result.fold((labels) {
      try {
        final entities = labels
            .map(LabelMapper.applicationLabelToLabelEntity)
            .toList(growable: false);
        return Ok(
          List.unmodifiable(_converter.convertToMetadataRecords(entities)),
        );
      } on Exception catch (_, st) {
        // Labels are private metadata, so neither values nor codec exceptions
        // are attached to logs.
        log.severe(
          message: 'Failed to encode BIP329 label metadata',
          error: StateError('BIP329 label metadata encoding failed'),
          trace: st,
        );
        return const Err(LabelUnexpectedFailure());
      }
    }, (failure) => Err(failure));
  }
}
