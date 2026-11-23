import 'package:primitives/primitives.dart' show Failure;

sealed class Bip85Failure extends Failure {
  const Bip85Failure([super.logMessage]);
}

final class Bip85NoDefaultWalletFailure extends Bip85Failure {
  const Bip85NoDefaultWalletFailure([super.logMessage]);
}

final class Bip85OperationFailure extends Bip85Failure {
  const Bip85OperationFailure();
}
