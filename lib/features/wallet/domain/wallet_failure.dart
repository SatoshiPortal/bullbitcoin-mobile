import 'package:bb_mobile/core/failures/failure.dart';

sealed class WalletFailure extends Failure {
  const WalletFailure([super.logMessage]);
}

final class WalletPendingTransactionsLoadFailure extends WalletFailure {
  const WalletPendingTransactionsLoadFailure([super.logMessage]);
}

final class WalletPendingTransactionDeleteFailure extends WalletFailure {
  const WalletPendingTransactionDeleteFailure([super.logMessage]);
}
