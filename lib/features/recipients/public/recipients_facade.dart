import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/entities/interac_security_details.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/update_interac_security_details_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/get_confidential_sepa_availability_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/entities/confidential_sepa_availability.dart';
import 'package:meta/meta.dart';

export '../ui/screens/recipient_selection_screen_v2.dart'
    show RecipientSelectionScreenV2;
export '../ui/screens/virtual_iban_onboarding_screen.dart'
    show VirtualIbanOnboardingScreen;
export '../domain/entities/confidential_sepa_availability.dart';
export '../domain/entities/recipient_type.dart' show RecipientType;
export '../recipients_locator.dart' show RecipientsLocator;
export '../ui/screens/recipients_screen.dart' show RecipientsScreen;
export '../ui/screens/sepa_virtual_payee_activation_screen.dart'
    show SepaVirtualPayeeActivationScreen;
export '../ui/screens/virtual_iban_funding_screen.dart'
    show VirtualIbanFundingScreen;
export 'package:bb_mobile/features/recipients/domain/entities/interac_security_details.dart';
export 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
export 'recipient_filter_criteria.dart' show RecipientFilterCriteria;
export 'recipient_selection.dart' show RecipientSelection;
export 'recipient_selection_screen.dart' show RecipientSelectionScreen;
export 'recipient_view_model.dart';

/// Public contract of the Recipients feature.
///
/// Other features must import Recipients-owned types, routes and screens
/// through this file instead of depending on its internal layers directly.
class RecipientsFacade {
  final UpdateInteracSecurityDetailsUsecase
  _updateInteracSecurityDetailsUsecase;
  final GetConfidentialSepaAvailabilityUsecase
  _getConfidentialSepaAvailabilityUsecase;

  RecipientsFacade(
    this._updateInteracSecurityDetailsUsecase,
    this._getConfidentialSepaAvailabilityUsecase,
  );

  @useResult
  Future<Result<ConfidentialSepaAvailability, RecipientsFailure>>
  getConfidentialSepaAvailability() =>
      _getConfidentialSepaAvailabilityUsecase.execute();

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
