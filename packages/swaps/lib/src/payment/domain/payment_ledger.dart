import 'package:primitives/primitives.dart';

import 'payment.dart';
import 'payment_ledger_failure.dart';

/// Internal durable admission authority. Commands persist facts only.
abstract interface class PaymentLedger {
  Future<Result<PaymentSnapshot?, PaymentLedgerFailure>> read(PaymentKey key);
  Future<Result<PaymentSnapshot, PaymentLedgerFailure>> createOrReadReview(
    BoundPaymentRequest request,
    PaymentReview review,
  );
  Future<Result<PaymentSnapshot, PaymentLedgerFailure>> replaceUnadmittedReview(
    PaymentKey key,
    int revision,
    PaymentReview review,
  );
  Future<Result<PaymentSnapshot, PaymentLedgerFailure>> beginPreflight(
    PaymentKey key,
    int revision,
    PaymentSource source,
    String operationId,
  );
  Future<Result<PaymentSnapshot, PaymentLedgerFailure>> closePreflightRefused(
    PaymentSnapshot expected,
    PaymentAttempt attempt,
    PreflightRefusal refusal,
  );
  Future<Result<PaymentSnapshot, PaymentLedgerFailure>> sealCreate(
    PaymentSnapshot expected,
    PaymentAttempt attempt,
  );
  Future<Result<PaymentSnapshot, PaymentLedgerFailure>> linkCreated(
    PaymentSnapshot expected,
    PaymentAttempt attempt,
    String backendReference,
  );
  Future<Result<PaymentSnapshot, PaymentLedgerFailure>> sealFunding(
    PaymentSnapshot expected,
    PaymentAttempt attempt,
  );
  Future<Result<PaymentSnapshot, PaymentLedgerFailure>> recordPending(
    PaymentSnapshot expected,
    PaymentAttempt attempt,
    PaymentReceipt receipt,
  );
  Future<Result<PaymentSnapshot, PaymentLedgerFailure>> recordUnknown(
    PaymentSnapshot expected,
    PaymentAttempt attempt,
  );
  Future<Result<PaymentSnapshot, PaymentLedgerFailure>> recordPaid(
    PaymentSnapshot expected,
    PaymentAttempt attempt,
    PaymentReceipt receipt,
  );
}
