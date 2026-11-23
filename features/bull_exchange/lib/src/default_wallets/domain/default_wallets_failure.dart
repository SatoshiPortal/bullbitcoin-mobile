import 'package:exchange/exchange.dart';
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

/// The save may have reached the exchange without a readable answer, so a new
/// recipient may exist. The default wallets are read again before another
/// save, so that save updates it instead of creating a second one.
final class DefaultWalletsSaveOutcomeUnknownFailure
    extends DefaultWalletsFailure {
  const DefaultWalletsSaveOutcomeUnknownFailure();
}

final class DefaultWalletsDeleteFailure extends DefaultWalletsFailure {
  const DefaultWalletsDeleteFailure();
}

final class DefaultWalletsInvalidAddressFailure extends DefaultWalletsFailure {
  final BtcNetwork type;

  const DefaultWalletsInvalidAddressFailure(this.type);
}
