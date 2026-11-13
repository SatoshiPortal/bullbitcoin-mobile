import 'package:primitives/primitives.dart' show Failure;

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
