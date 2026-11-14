import 'package:primitives/primitives.dart' show Failure;

sealed class DefaultWalletFailure extends Failure {
  const DefaultWalletFailure([super.logMessage]);
}

final class DefaultWalletAlreadyExistsFailure extends DefaultWalletFailure {
  const DefaultWalletAlreadyExistsFailure();
}

final class DefaultWalletMnemonicRequiredFailure extends DefaultWalletFailure {
  const DefaultWalletMnemonicRequiredFailure();
}

final class DefaultWalletStorageFailure extends DefaultWalletFailure {
  const DefaultWalletStorageFailure();
}

final class DefaultWalletSecretFailure extends DefaultWalletFailure {
  const DefaultWalletSecretFailure();
}

final class DefaultWalletCreationFailure extends DefaultWalletFailure {
  const DefaultWalletCreationFailure();
}

final class DefaultWalletUnexpectedFailure extends DefaultWalletFailure {
  const DefaultWalletUnexpectedFailure();
}
