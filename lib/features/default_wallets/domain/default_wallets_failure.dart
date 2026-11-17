import 'package:primitives/primitives.dart' show Failure;

sealed class DefaultWalletsFailure extends Failure {
  const DefaultWalletsFailure();
}

final class DefaultWalletsLoadFailure extends DefaultWalletsFailure {
  const DefaultWalletsLoadFailure();
}

final class DefaultWalletsEmptyAddressFailure extends DefaultWalletsFailure {
  const DefaultWalletsEmptyAddressFailure();
}

final class DefaultWalletsSaveFailure extends DefaultWalletsFailure {
  const DefaultWalletsSaveFailure();
}

final class DefaultWalletsDeleteFailure extends DefaultWalletsFailure {
  const DefaultWalletsDeleteFailure();
}
