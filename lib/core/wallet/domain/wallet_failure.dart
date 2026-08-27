import 'package:bb_mobile/core/failures/failure.dart';

sealed class WalletFailure extends Failure {
  const WalletFailure([super.logMessage]);
}

final class WalletTransactionLookupFailure extends WalletFailure {
  const WalletTransactionLookupFailure([super.logMessage]);
}
