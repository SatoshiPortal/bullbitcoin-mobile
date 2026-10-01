import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/entities/virtual_iban.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/watch_virtual_iban_activation_usecase.dart';

export '../domain/entities/virtual_iban.dart' show VirtualIban;
export '../domain/recipients_failure.dart'
    show
        RecipientsFailure,
        VirtualIbanEuResidencyRequiredFailure,
        VirtualIbanFailure,
        VirtualIbanNotAvailableFailure;
export '../domain/value_objects/recipient_type.dart' show RecipientType;
export '../domain/value_objects/sepa_payment_option.dart'
    show SepaPaymentOption;
export '../domain/value_objects/sepa_virtual_payee_status.dart'
    show SepaVirtualPayeeStatus;
export '../domain/value_objects/virtual_iban_status.dart'
    show VirtualIbanStatus;
export 'recipient_filter_criteria.dart' show RecipientFilterCriteria;
export 'recipient_view_model.dart';

/// Public contract of the Recipients feature.
///
/// Other features must import Recipients-owned types through this file instead
/// of depending on its internal layers directly. This surface is Flutter-free
/// so domain-layer consumers can depend on it; the feature's UI is published
/// separately through `recipients_ui.dart`.
class RecipientsFacade {
  final WatchVirtualIbanActivationUsecase _watchVirtualIbanActivationUsecase;

  const RecipientsFacade(this._watchVirtualIbanActivationUsecase);

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
