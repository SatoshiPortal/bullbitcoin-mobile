import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart' show Failure;

sealed class DefaultWalletsFailure extends Failure {
  const DefaultWalletsFailure();
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

/// Another exchange write of the account is running (or the journal can't
/// tell whether one is unsettled): nothing was sent.
final class DefaultWalletsBusyFailure extends DefaultWalletsFailure {
  const DefaultWalletsBusyFailure();
}

final class DefaultWalletsInvalidAddressFailure extends DefaultWalletsFailure {
  final BtcNetwork type;

  const DefaultWalletsInvalidAddressFailure(this.type);

  @override
  bool operator ==(Object other) =>
      other is DefaultWalletsInvalidAddressFailure && other.type == type;

  @override
  int get hashCode => Object.hash(DefaultWalletsInvalidAddressFailure, type);
}
