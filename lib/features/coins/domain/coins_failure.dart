import 'package:bb_mobile/core/failures/failure.dart';

sealed class CoinsFailure extends Failure {
  const CoinsFailure([super.logMessage]);
}

final class CoinsLoadFailure extends CoinsFailure {
  const CoinsLoadFailure([super.logMessage]);
}

final class CoinsFreezeFailure extends CoinsFailure {
  const CoinsFreezeFailure([super.logMessage]);
}

final class CoinsUnfreezeFailure extends CoinsFailure {
  const CoinsUnfreezeFailure([super.logMessage]);
}

final class CoinsUnexpectedFailure extends CoinsFailure {
  const CoinsUnexpectedFailure([super.logMessage]);
}
