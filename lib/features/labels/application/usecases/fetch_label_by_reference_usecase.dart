import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/adapters/label_mapper.dart';
import 'package:bb_mobile/features/labels/application/application_label.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:meta/meta.dart';

class FetchLabelByReferenceUsecase {
  final LabelsRepositoryPort _labelRepository;

  FetchLabelByReferenceUsecase({required this._labelRepository});

  @useResult
  Future<Result<List<ApplicationLabel>, LabelFailure>> execute(
    String reference,
  ) async {
    try {
      final labels = await _labelRepository.fetchByReference(reference);
      return Ok(
        labels
            .map((label) => LabelMapper.labelEntityToApplicationLabel(label))
            .toList(),
      );
    } catch (e, st) {
      // Keep the technical reason in the logs; the failure carries only the
      // logged-only reason and the UI maps it to a generic message. The
      // reference is a txid/address/xpub — keep it OUT of the Sentry-bound
      // message to avoid leaking an on-chain identifier off-device.
      log.severe(
        message: 'Failed to fetch label by reference',
        error: e,
        trace: st,
      );
      return Err(LabelUnexpectedFailure('$e'));
    }
  }
}
