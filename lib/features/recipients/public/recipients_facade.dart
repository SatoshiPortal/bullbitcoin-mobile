import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/interac_security_details.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/update_interac_security_details_usecase.dart';

export 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
export 'package:bb_mobile/features/recipients/domain/interac_security_details.dart';
export 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
export 'package:bb_mobile/features/recipients/public/recipient_selection.dart';
export 'package:bb_mobile/features/recipients/public/recipient_selection_screen.dart';

class RecipientsFacade {
  final UpdateInteracSecurityDetailsUsecase
  _updateInteracSecurityDetailsUsecase;

  RecipientsFacade(this._updateInteracSecurityDetailsUsecase);

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
