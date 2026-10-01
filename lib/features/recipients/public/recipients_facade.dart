import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/entities/virtual_iban.dart';
import 'package:bb_mobile/features/recipients/domain/interac_security_details.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/update_interac_security_details_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/watch_virtual_iban_activation_usecase.dart';

export 'package:bb_mobile/features/recipients/domain/interac_security_details.dart';
export 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';

export '../domain/entities/virtual_iban.dart' show VirtualIban;
export '../domain/value_objects/recipient_type.dart' show RecipientType;
export '../domain/value_objects/sepa_payment_option.dart'
    show SepaPaymentOption;
export '../domain/value_objects/sepa_virtual_payee_status.dart'
    show SepaVirtualPayeeStatus;
export '../domain/value_objects/virtual_iban_status.dart'
    show VirtualIbanStatus;
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
  final WatchVirtualIbanActivationUsecase _watchVirtualIbanActivationUsecase;

  RecipientsFacade(
    this._updateInteracSecurityDetailsUsecase,
    this._watchVirtualIbanActivationUsecase,
  );

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

  /// Emits the user's virtual IBAN, polling while activation is pending.
  ///
  /// With [createIfAbsent] false the first emission doubles as a
  /// status/permission check; with true an absent virtual IBAN is created
  /// before polling.
  Stream<Result<VirtualIban, RecipientsFailure>> watchVirtualIbanActivation({
    required bool createIfAbsent,
  }) => _watchVirtualIbanActivationUsecase.execute(
    createIfAbsent: createIfAbsent,
  );
}
