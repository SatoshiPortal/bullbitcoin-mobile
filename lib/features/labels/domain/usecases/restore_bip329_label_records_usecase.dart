import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/application/labels_converter_port.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/bip329_label_record.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:meta/meta.dart';

final class RestoreBip329LabelRecordsUsecase {
  final LabelsRepositoryPort _repository;
  final LabelsConverterPort _converter;

  const RestoreBip329LabelRecordsUsecase(this._repository, this._converter);

  @useResult
  Future<Result<Bip329LabelRestoreSummary, LabelFailure>> execute(
    List<Bip329LabelRecord> records,
  ) async {
    try {
      final desiredById = <String, Bip329LabelRecord>{};
      for (final record in records) {
        if (desiredById.containsKey(record.recordId)) {
          throw const FormatException('Duplicate BIP329 metadata identity');
        }
        desiredById[record.recordId] = record;
      }
      final decoded = _converter.convertFromMetadataRecords(records);
      if (decoded.length != records.length) {
        throw const FormatException('BIP329 metadata conversion lost records');
      }
      final writeResult = await _repository.restoreMissing(decoded);
      if (writeResult.intendedCount != records.length) {
        throw const FormatException('BIP329 recovery write lost records');
      }
      return Ok(
        Bip329LabelRestoreSummary(
          intendedCount: records.length,
          restoredCount: writeResult.restoredCount,
          alreadyPresentCount: writeResult.alreadyPresentCount,
          preservedLocalConflictCount: writeResult.preservedLocalConflictCount,
          localProjectionMatchesSnapshot:
              writeResult.preservedLocalConflictCount == 0,
        ),
      );
    } on Exception catch (_, st) {
      log.severe(
        message: 'Failed to restore BIP329 metadata labels',
        error: StateError('BIP329 metadata label restore failed'),
        trace: st,
      );
      return const Err(LabelUnexpectedFailure());
    }
  }
}
