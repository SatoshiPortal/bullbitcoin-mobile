import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'background_wallet_sync_port.dart';

/// Announces the payments a background sync found. Implemented outside this
/// package and injected; it never changes the result of a committed sync.
abstract interface class PaymentAnnouncementPort {
  /// Records the complete incoming history of [outcome], if it has one.
  @useResult
  Future<Result<void, PaymentAnnouncementFailure>> record(
    BackgroundSyncOutcome outcome,
  );

  /// Shows the announcements waiting for delivery.
  @useResult
  Future<Result<void, PaymentAnnouncementFailure>> deliverPending();
}

sealed class PaymentAnnouncementFailure extends Failure {
  const PaymentAnnouncementFailure();
}

/// The OS shows no notification for the app: the pending announcements were
/// dropped, so a later run has nothing to retry.
final class PaymentAnnouncementDeniedFailure
    extends PaymentAnnouncementFailure {
  const PaymentAnnouncementDeniedFailure();
}

/// Storage, platform or an undetermined permission: a later run retries.
final class PaymentAnnouncementUnavailableFailure
    extends PaymentAnnouncementFailure {
  const PaymentAnnouncementUnavailableFailure();
}
