import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:meta/meta.dart';

class TrashLabelUsecase {
  final LabelsRepositoryPort _labelRepository;

  TrashLabelUsecase({required this._labelRepository});

  @useResult
  Future<Result<Null, LabelFailure>> execute(int id) async {
    try {
      await _labelRepository.trash(id);
      return const Ok(null);
    } catch (e, st) {
      // Keep the technical reason in the logs; the failure carries only the
      // logged-only reason and the UI maps it to a generic message.
      log.severe(message: 'Failed to trash label $id', error: e, trace: st);
      return Err(LabelUnexpectedFailure('$e'));
    }
  }
}
