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
      final existing = _converter.convertToMetadataRecords(
        await _repository.fetchAll(),
      );
      final existingById = {
        for (final record in existing) record.recordId: record,
      };
      var alreadyPresentCount = 0;
      var preservedLocalConflictCount = 0;
      final toStore = <int>[];
      for (var index = 0; index < records.length; index++) {
        final record = records[index];
        final current = existingById[record.recordId];
        if (current == null) {
          toStore.add(index);
        } else if (_sameLabel(current, record)) {
          alreadyPresentCount++;
        } else {
          preservedLocalConflictCount++;
        }
      }
      await _repository.storeAll(
        toStore.map((index) => decoded[index]).toList(growable: false),
      );
      return Ok(
        Bip329LabelRestoreSummary(
          intendedCount: records.length,
          restoredCount: toStore.length,
          alreadyPresentCount: alreadyPresentCount,
          preservedLocalConflictCount: preservedLocalConflictCount,
          localProjectionMatchesSnapshot: preservedLocalConflictCount == 0,
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

bool _sameLabel(Bip329LabelRecord left, Bip329LabelRecord right) {
  return left.type == right.type &&
      left.reference == right.reference &&
      left.label == right.label &&
      left.origin == right.origin;
}
