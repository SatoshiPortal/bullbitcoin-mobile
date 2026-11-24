import 'package:ark/ark.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/ark_failure.dart';

/// The enabled Ark accounts of a network, resolved by the foreground host from
/// the current runtime's local inventory and preferences on every request.
///
/// Local inventory and routing preference only: this capability grants no
/// funding, quote or signing authority, and reading it never opens a wallet.
final class ArkAccountsFacade {
  final Future<Result<List<ArkAccountId>, ArkFailure>> Function(BitcoinNetwork)
  _listEnabled;
  const ArkAccountsFacade(this._listEnabled);
  @useResult
  Future<Result<List<ArkAccountId>, ArkFailure>> listEnabled(
    BitcoinNetwork network,
  ) => _listEnabled(network);
}
