import 'package:bb_mobile/core/failures/failure.dart';

sealed class Bip85Failure extends Failure {
  const Bip85Failure([super.logMessage]);
}

final class Bip85NoDefaultWalletFailure extends Bip85Failure {
  const Bip85NoDefaultWalletFailure([super.logMessage]);
}

final class Bip85DerivationFailure extends Bip85Failure {
  const Bip85DerivationFailure([super.logMessage]);
}

final class Bip85StorageFailure extends Bip85Failure {
  const Bip85StorageFailure([super.logMessage]);
}

final class Bip85UnexpectedFailure extends Bip85Failure {
  const Bip85UnexpectedFailure([super.logMessage]);
}
