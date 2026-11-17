import 'package:primitives/primitives.dart';

/// Internal persistence failures; later integration maps to SwapsFailure.
sealed class PaymentLedgerFailure extends Failure {
  static const conflict = PaymentLedgerConflict();
  static const stale = PaymentLedgerStale();
  static const recoveryRequired = PaymentLedgerRecoveryRequired();
  static const busy = PaymentLedgerBusy();
  static const storage = PaymentLedgerStorage();

  const PaymentLedgerFailure();
}

final class PaymentLedgerConflict extends PaymentLedgerFailure {
  const PaymentLedgerConflict();
}

final class PaymentLedgerStale extends PaymentLedgerFailure {
  const PaymentLedgerStale();
}

final class PaymentLedgerRecoveryRequired extends PaymentLedgerFailure {
  const PaymentLedgerRecoveryRequired();
}

final class PaymentLedgerBusy extends PaymentLedgerFailure {
  const PaymentLedgerBusy();
}

final class PaymentLedgerStorage extends PaymentLedgerFailure {
  const PaymentLedgerStorage();
}
