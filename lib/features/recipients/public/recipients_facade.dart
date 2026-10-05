import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/interac_security_details.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/update_interac_security_details_usecase.dart';
import 'package:meta/meta.dart';

export '../domain/value_objects/recipient_type.dart' show RecipientType;
export 'package:bb_mobile/features/recipients/domain/interac_security_details.dart';
export 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
export 'recipient_filter_criteria.dart' show RecipientFilterCriteria;
export 'recipient_selection.dart' show RecipientSelection;
export 'recipient_view_model.dart';

/// Public contract of the Recipients feature.
///
/// Other features must import Recipients-owned types through this file instead
/// of depending on its internal layers directly. This surface is Flutter-free
/// so domain-layer consumers can depend on it; the feature's UI is published
/// separately through `recipients_ui.dart`.
class RecipientsFacade {
  final UpdateInteracSecurityDetailsUsecase
  _updateInteracSecurityDetailsUsecase;

  RecipientsFacade(this._updateInteracSecurityDetailsUsecase);

  @useResult
  Future<Result<void, RecipientsFailure>> updateInteracSecurityDetails({
    required String recipientId,
    required String email,
    required String? securityQuestion,
    required String? securityAnswer,
  }) {
    final detailsResult = InteracSecurityDetails.create(
      recipientId: recipientId,
      email: email,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
    );
    return switch (detailsResult) {
      Ok(:final value) => _updateInteracSecurityDetailsUsecase.execute(value),
      Err(:final failure) => Future.value(Err(failure)),
    };
  }
}
