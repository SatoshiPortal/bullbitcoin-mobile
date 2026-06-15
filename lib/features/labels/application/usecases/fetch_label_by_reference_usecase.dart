import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/labels/adapters/label_mapper.dart';
import 'package:bb_mobile/features/labels/application/application_label.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/domain/label_error.dart';

class FetchLabelByReferenceUsecase {
  final LabelsRepositoryPort _labelRepository;

  FetchLabelByReferenceUsecase({required this._labelRepository});

  Future<List<ApplicationLabel>> execute(String reference) async {
    try {
      final labels = await _labelRepository.fetchByReference(reference);
      return labels
          .map((label) => LabelMapper.labelEntityToApplicationLabel(label))
          .toList();
    } on LabelError {
      rethrow;
    } catch (e, st) {
      // Keep the technical reason in the logs; the UI maps the unexpected
      // variant to a generic message and never shows [e]. The reference is a
      // txid/address/xpub — keep it OUT of the Sentry-bound message to avoid
      // leaking an on-chain identifier off-device.
      log.severe(message: 'Failed to fetch label by reference', error: e, trace: st);
      throw UnexpectedLabelError('Failed to fetch label by reference: $e');
    }
  }
}
